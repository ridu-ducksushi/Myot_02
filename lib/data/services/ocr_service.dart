import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
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
  static TextRecognizer? _textRecognizer;
  
  /// TextRecognizer 인스턴스 (lazy initialization)
  static TextRecognizer get _recognizer {
    _textRecognizer ??= TextRecognizer(script: TextRecognitionScript.korean);
    return _textRecognizer!;
  }
  
  /// 리소스 정리
  static Future<void> dispose() async {
    await _textRecognizer?.close();
    _textRecognizer = null;
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
  
  /// 이미지에서 텍스트 인식
  static Future<String> recognizeText(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognizedText = await _recognizer.processImage(inputImage);
    return recognizedText.text;
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
    return text
        .replaceAll('\r', '\n')
        .replaceAll('\t', ' ')
        .replaceAllMapped(RegExp(r'[^\S\r\n]+'), (match) => ' ')
        .toUpperCase();
  }

  static String? _extractValueFromText(String normalizedText, String alias) {
    final aliasPattern = _aliasToPattern(alias);
    final directPattern = RegExp(
      r'(?<![A-Z0-9])' + aliasPattern + r'(?:\s*[:=]?\s*)(-?\d+(?:\.\d+)?)',
      caseSensitive: false,
    );
    final directMatch = directPattern.firstMatch(normalizedText);
    if (directMatch != null) {
      return directMatch.group(1);
    }

    // 숫자가 키워드 앞에 오는 경우 (예: 45 ALT)
    final reversedPattern = RegExp(
      r'(-?\d+(?:\.\d+)?)\s*(?:[=:])?\s*' + aliasPattern,
      caseSensitive: false,
    );
    final reversedMatch = reversedPattern.firstMatch(normalizedText);
    if (reversedMatch != null) {
      return reversedMatch.group(1);
    }

    // 느슨한 검색: 키워드 주변 범위 내 숫자 추출
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

