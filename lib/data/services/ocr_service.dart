import 'dart:io';
import 'dart:typed_data';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:petcare/data/services/lab_reference_ranges.dart';

/// OCR 서비스 - 건강검진표 이미지에서 검사 수치 인식
class OcrService {
  OcrService._();
  
  // 상수
  static const int _imageQuality = 90;
  static const int _searchRangeAfter = 60;
  static const int _searchRangeBefore = 30;
  static const String _errorCameraUnavailable = '카메라를 사용할 수 없습니다';
  
  static final _picker = ImagePicker();
  static TextRecognizer? _koreanRecognizer;
  static TextRecognizer? _latinRecognizer;
  
  /// 한국어 TextRecognizer 인스턴스 (lazy initialization)
  static TextRecognizer get _koreanRec {
    _koreanRecognizer ??= TextRecognizer(script: TextRecognitionScript.korean);
    return _koreanRecognizer!;
  }
  
  /// 라틴 스크립트 TextRecognizer 인스턴스 (lazy initialization)
  static TextRecognizer get _latinRec {
    _latinRecognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
    return _latinRecognizer!;
  }
  
  /// 리소스 정리
  static Future<void> dispose() async {
    await _koreanRecognizer?.close();
    await _latinRecognizer?.close();
    _koreanRecognizer = null;
    _latinRecognizer = null;
  }
  
  /// 카메라로 이미지 촬영
  static Future<File?> pickFromCamera() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: _imageQuality,
      );
      return image != null ? File(image.path) : null;
    } catch (e) {
      throw Exception('$_errorCameraUnavailable: $e');
    }
  }
  
  /// 갤러리에서 이미지 선택
  static Future<File?> pickFromGallery() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: _imageQuality,
      );
      return image != null ? File(image.path) : null;
    } catch (e) {
      throw Exception('갤러리에서 이미지를 불러올 수 없습니다: $e');
    }
  }
  
  /// 이미지 전처리 (명도, 대비 개선)
  static Future<File?> _preprocessImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      if (image == null) return null;
      
      // 그레이스케일 변환 (OCR 정확도 향상)
      image = img.grayscale(image);
      
      // 대비 개선
      image = img.adjustColor(
        image,
        contrast: 1.2,
        brightness: 1.1,
      );
      
      // 선명도 개선
      image = img.convolution(image, filter: [
        0, -1, 0,
        -1, 5, -1,
        0, -1, 0,
      ]);
      
      // 임시 파일로 저장 (원본 확장자 유지)
      final extension = imageFile.path.split('.').last.toLowerCase();
      final processedBytes = extension == 'png' 
          ? img.encodePng(image)
          : img.encodeJpg(image, quality: 95);
      final tempFile = File('${imageFile.path}_processed.$extension');
      await tempFile.writeAsBytes(processedBytes);
      return tempFile;
    } catch (e) {
      // 전처리 실패 시 원본 파일 반환
      return imageFile;
    }
  }
  
  /// 이미지에서 텍스트 인식 (다중 스크립트 지원)
  static Future<String> recognizeText(File imageFile) async {
    // 이미지 전처리
    final processedFile = await _preprocessImage(imageFile) ?? imageFile;
    
    try {
      final inputImage = InputImage.fromFile(processedFile);
      
      // 한국어와 라틴 스크립트 동시 인식
      final koreanResult = await _koreanRec.processImage(inputImage);
      final latinResult = await _latinRec.processImage(inputImage);
      
      // 두 결과를 결합 (더 긴 텍스트 우선)
      final koreanText = koreanResult.text.trim();
      final latinText = latinResult.text.trim();
      
      // 텍스트 길이와 품질을 고려하여 선택
      if (koreanText.length > latinText.length * 0.7) {
        return koreanText;
      } else if (latinText.length > koreanText.length * 0.7) {
        return latinText;
      } else {
        // 두 결과를 결합 (중복 제거)
        return _mergeTexts(koreanText, latinText);
      }
    } finally {
      // 전처리된 임시 파일 삭제
      if (processedFile.path != imageFile.path && processedFile.existsSync()) {
        try {
          await processedFile.delete();
        } catch (_) {
          // 삭제 실패는 무시
        }
      }
    }
  }
  
  /// 두 텍스트 결과를 병합 (중복 제거)
  static String _mergeTexts(String text1, String text2) {
    if (text1.isEmpty) return text2;
    if (text2.isEmpty) return text1;
    
    // 더 긴 텍스트를 기준으로 병합
    final base = text1.length > text2.length ? text1 : text2;
    final supplement = text1.length > text2.length ? text2 : text1;
    
    // 보완 텍스트에서 새로 추가할 부분만 추출
    final baseLines = base.split('\n');
    final suppLines = supplement.split('\n');
    
    final merged = <String>[];
    for (final line in baseLines) {
      merged.add(line);
    }
    
    // 보완 텍스트에서 유사하지 않은 라인 추가
    for (final suppLine in suppLines) {
      if (suppLine.trim().isEmpty) continue;
      bool isDuplicate = false;
      for (final baseLine in baseLines) {
        if (_isSimilarLine(suppLine, baseLine)) {
          isDuplicate = true;
          break;
        }
      }
      if (!isDuplicate) {
        merged.add(suppLine);
      }
    }
    
    return merged.join('\n');
  }
  
  /// 두 라인이 유사한지 확인 (편집 거리 기반)
  static bool _isSimilarLine(String line1, String line2) {
    if (line1.isEmpty || line2.isEmpty) return false;
    final l1 = line1.trim().toLowerCase();
    final l2 = line2.trim().toLowerCase();
    
    // 완전 일치
    if (l1 == l2) return true;
    
    // 한쪽이 다른 쪽을 포함
    if (l1.contains(l2) || l2.contains(l1)) return true;
    
    // 길이 차이가 크면 다른 라인
    if ((l1.length - l2.length).abs() > l1.length * 0.5) return false;
    
    // 공통 문자 비율 확인
    final commonChars = _countCommonChars(l1, l2);
    final similarity = commonChars / (l1.length + l2.length - commonChars);
    return similarity > 0.6;
  }
  
  /// 공통 문자 개수 계산
  static int _countCommonChars(String s1, String s2) {
    final chars1 = s1.split('');
    final chars2 = s2.split('').toList();
    int count = 0;
    for (final char in chars1) {
      final index = chars2.indexOf(char);
      if (index != -1) {
        count++;
        chars2.removeAt(index);
      }
    }
    return count;
  }
  
  /// 인식된 텍스트에서 검사 항목과 수치 파싱
  static Map<String, String> parseLabResults(String text) {
    final results = <String, String>{};
    final normalizedText = _normalizeText(text);
    final keywords = _buildKeywordMap();

    for (final entry in keywords.entries) {
      final testName = entry.key;
      final aliases = entry.value;

      for (final alias in aliases) {
        final value = _extractValueFromText(normalizedText, alias);
        if (value != null && value.isNotEmpty) {
          results.putIfAbsent(testName, () => value);
          break;
        }
      }
    }

    return results;
  }
  
  /// 키워드 맵 생성 (검사 항목명 → 가능한 키워드 목록)
  static Map<String, List<String>> _buildKeywordMap() {
    return {
      // 혈액 검사 (CBC)
      'RBC': ['RBC', 'Red Blood Cell', '적혈구', '적혈구수'],
      'WBC': ['WBC', 'White Blood Cell', '백혈구', '백혈구수'],
      'HGB': ['HGB', 'Hb', 'Hemoglobin', '헤모글로빈', '혈색소'],
      'HCT': ['HCT', 'Hematocrit', '헤마토크릿', '적혈구용적'],
      'PLT': ['PLT', 'Platelet', '혈소판', '혈소판수'],
      'MCV': ['MCV', '평균적혈구용적'],
      'MCH': ['MCH', '평균적혈구혈색소'],
      'MCHC': ['MCHC', '평균적혈구혈색소농도'],
      'RDW-CV': ['RDW-CV', 'RDW', '적혈구분포폭'],
      'MPV': ['MPV', '평균혈소판용적'],
      
      // 백혈구 감별계산
      'WBC-GRAN(#)': ['WBC-GRAN(#)', 'GRAN#', 'NEU#', '과립구수', '호중구수'],
      'WBC-GRAN(%)': ['WBC-GRAN(%)', 'GRAN%', 'NEU%', '과립구%', '호중구%'],
      'WBC-LYM(#)': ['WBC-LYM(#)', 'LYM#', '림프구수'],
      'WBC-LYM(%)': ['WBC-LYM(%)', 'LYM%', '림프구%'],
      'WBC-MONO(#)': ['WBC-MONO(#)', 'MONO#', '단핵구수'],
      'WBC-MONO(%)': ['WBC-MONO(%)', 'MONO%', '단핵구%'],
      'WBC-EOS(#)': ['WBC-EOS(#)', 'EOS#', '호산구수'],
      'WBC-EOS(%)': ['WBC-EOS(%)', 'EOS%', '호산구%'],
      
      // 간기능 검사
      'ALT GPT': ['ALT', 'GPT', 'ALT GPT', 'ALT(GPT)', 'SGPT', '알라닌아미노전이효소'],
      'AST GOT': ['AST', 'GOT', 'AST GOT', 'AST(GOT)', 'SGOT', '아스파르테이트아미노전이효소'],
      'ALP': ['ALP', 'Alkaline Phosphatase', '알칼리인산분해효소', '알칼리포스파타제'],
      'GGT': ['GGT', 'γ-GT', 'Gamma GT', '감마지티'],
      'TBIL': ['TBIL', 'T-Bil', 'Total Bilirubin', '총빌리루빈', '빌리루빈'],
      
      // 신장기능 검사
      'BUN': ['BUN', 'Blood Urea Nitrogen', '혈중요소질소', '요소질소'],
      'CREA': ['CREA', 'Creatinine', 'CRE', '크레아티닌'],
      'SDMA': ['SDMA', '대칭디메틸아르기닌'],
      
      // 전해질
      'Na': ['Na', 'Sodium', '나트륨'],
      'K': ['K', 'Potassium', '칼륨'],
      'Cl': ['Cl', 'Chloride', '염소'],
      'Ca': ['Ca', 'Calcium', '칼슘'],
      'PHOS': ['PHOS', 'P', 'Phosphorus', '인'],
      
      // 단백질
      'TPRO': ['TPRO', 'TP', 'Total Protein', '총단백', '총단백질'],
      'ALB': ['ALB', 'Albumin', '알부민'],
      'GLOB': ['GLOB', 'Globulin', '글로불린'],
      
      // 지질
      'T-CHOL': ['T-CHOL', 'CHOL', 'TC', 'Total Cholesterol', '총콜레스테롤', '콜레스테롤'],
      'TG': ['TG', 'Triglyceride', '중성지방'],
      
      // 기타
      'GLU': ['GLU', 'Glucose', '혈당', '포도당'],
      'CK': ['CK', 'CPK', 'Creatine Kinase', '크레아틴키나아제'],
      'LIPA': ['LIPA', 'Lipase', '리파아제'],
      'NH3': ['NH3', 'Ammonia', '암모니아'],
      
      // 비율
      'Na/K': ['Na/K', 'Na:K'],
      'ALB/GLB': ['ALB/GLB', 'A/G', 'A:G', 'A/G비'],
      'BUN/CRE': ['BUN/CRE', 'BUN/CREA', 'BUN:CRE'],
      'vAMY-P': ['vAMY-P', 'AMY', 'Amylase', '아밀라아제'],
    };
  }
  
  static String _normalizeText(String text) {
    // 기본 정규화
    var normalized = text
        .replaceAll('\r', '\n')
        .replaceAll('\t', ' ')
        .replaceAllMapped(RegExp(r'[^\S\r\n]+'), (match) => ' ')
        .toUpperCase();
    
    // OCR 자주 발생하는 오타 보정
    normalized = _fixCommonOcrErrors(normalized);
    
    return normalized;
  }
  
  /// OCR에서 자주 발생하는 오타 보정
  static String _fixCommonOcrErrors(String text) {
    // 숫자와 문자 혼동 (예: 0 → O, 1 → I, 5 → S)
    // 하지만 검사 항목명에서는 보정하지 않음 (ALB, ALT 등)
    
    // 공백 제거 및 정리
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    
    // 특수문자 정리
    text = text.replaceAll(RegExp(r'[|]'), 'I'); // | → I
    text = text.replaceAll(RegExp(r'[`]'), ''); // 백틱 제거
    
    return text;
  }

  static String? _extractValueFromText(String normalizedText, String alias) {
    final aliasPattern = _aliasToPattern(alias);
    
    // 패턴 1: 키워드 바로 뒤 숫자 (예: ALT: 45, ALT = 45, ALT 45)
    final directPattern = RegExp(
      r'(?<![A-Z0-9])' + aliasPattern + r'(?:\s*[:=]?\s*)(-?\d+(?:\.\d+)?)',
      caseSensitive: false,
    );
    final directMatch = directPattern.firstMatch(normalizedText);
    if (directMatch != null) {
      return directMatch.group(1);
    }

    // 패턴 2: 숫자가 키워드 앞에 오는 경우 (예: 45 ALT, 45=ALT)
    final reversedPattern = RegExp(
      r'(-?\d+(?:\.\d+)?)\s*(?:[=:])?\s*' + aliasPattern,
      caseSensitive: false,
    );
    final reversedMatch = reversedPattern.firstMatch(normalizedText);
    if (reversedMatch != null) {
      return reversedMatch.group(1);
    }

    // 패턴 3: 키워드와 숫자가 같은 라인에 있는 경우 (표 형식)
    final lines = normalizedText.split('\n');
    for (final line in lines) {
      final lowerLine = line.toLowerCase();
      final lowerAlias = alias.toLowerCase();
      if (lowerLine.contains(lowerAlias)) {
        // 라인에서 숫자 추출
        final numbers = RegExp(r'-?\d+(?:\.\d+)?').allMatches(line).toList();
        if (numbers.isNotEmpty) {
          // 키워드 위치 기준으로 가장 가까운 숫자 선택
          final aliasIndex = lowerLine.indexOf(lowerAlias);
          String? closestValue;
          int minDistance = 999;
          
          for (final match in numbers) {
            final numIndex = match.start;
            final distance = (numIndex - aliasIndex).abs();
            if (distance < minDistance) {
              minDistance = distance;
              closestValue = match.group(0);
            }
          }
          
          if (closestValue != null && minDistance < 50) {
            return closestValue;
          }
        }
      }
    }

    // 패턴 4: 느슨한 검색 - 키워드 주변 범위 내 숫자 추출
    final lowerText = normalizedText.toLowerCase();
    final lowerAlias = alias.toLowerCase();
    final idx = lowerText.indexOf(lowerAlias);
    if (idx != -1) {
      final end = idx + lowerAlias.length;
      final afterSlice = normalizedText.substring(
        end,
        end + _searchRangeAfter > normalizedText.length 
            ? normalizedText.length 
            : end + _searchRangeAfter,
      );
      final afterMatch = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(afterSlice);
      if (afterMatch != null) {
        return afterMatch.group(0);
      }

      final beforeSlice = normalizedText.substring(
        idx - _searchRangeBefore < 0 ? 0 : idx - _searchRangeBefore,
        idx,
      );
      final beforeMatches = RegExp(r'-?\d+(?:\.\d+)?')
          .allMatches(beforeSlice)
          .toList();
      if (beforeMatches.isNotEmpty) {
        return beforeMatches.last.group(0);
      }
    }

    return null;
  }

  static String _aliasToPattern(String alias) {
    final cleaned = alias.trim();
    final segments = cleaned.split(RegExp(r'\s+'));
    return segments.map((segment) {
      final escaped = RegExp.escape(segment)
          .replaceAll(r'\(', r'\(')
          .replaceAll(r'\)', r'\)');
      return escaped;
    }).join(r'\s*');
  }
  
  /// OCR 결과를 현재 저장된 검사 항목에 맞게 매핑
  /// [ocrResults] OCR로 파싱된 결과
  /// [existingKeys] 기존에 저장된 검사 항목 키 목록
  static Map<String, String> mapToExistingKeys(
    Map<String, String> ocrResults,
    List<String> existingKeys,
  ) {
    final mapped = <String, String>{};
    
    for (final entry in ocrResults.entries) {
      // 기존 키에 있는 경우 그대로 사용
      if (existingKeys.contains(entry.key)) {
        mapped[entry.key] = entry.value;
      }
    }
    
    return mapped;
  }
}

/// OCR 인식 결과 모델
class OcrLabResult {
  final String testName;
  final String value;
  final String? unit;
  final String? reference;
  final bool isConfident; // OCR 인식 신뢰도
  
  const OcrLabResult({
    required this.testName,
    required this.value,
    this.unit,
    this.reference,
    this.isConfident = true,
  });
  
  OcrLabResult copyWith({
    String? testName,
    String? value,
    String? unit,
    String? reference,
    bool? isConfident,
  }) {
    return OcrLabResult(
      testName: testName ?? this.testName,
      value: value ?? this.value,
      unit: unit ?? this.unit,
      reference: reference ?? this.reference,
      isConfident: isConfident ?? this.isConfident,
    );
  }
}

