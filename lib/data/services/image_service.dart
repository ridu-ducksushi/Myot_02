import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ImageService {
  static final ImagePicker _picker = ImagePicker();

  /// 갤러리에서 이미지 선택
  static Future<File?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('❌ 갤러리에서 이미지 선택 실패: $e');
      return null;
    }
  }

  /// 카메라로 이미지 촬영
  static Future<File?> pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('❌ 카메라로 이미지 촬영 실패: $e');
      return null;
    }
  }

  /// 이미지 압축
  static Future<File?> compressImage(File imageFile) async {
    try {
      final directory = await getTemporaryDirectory();
      final targetPath = path.join(
        directory.path,
        '${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        targetPath,
        quality: 80,
        minWidth: 300,
        minHeight: 300,
      );

      return compressedFile != null ? File(compressedFile.path) : null;
    } catch (e) {
      print('❌ 이미지 압축 실패: $e');
      return null;
    }
  }

  /// 이미지를 앱 내부 저장소에 저장
  static Future<String?> saveImageToAppDirectory(File imageFile) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(path.join(directory.path, 'pet_images'));
      
      // 이미지 디렉토리가 없으면 생성
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedImage = File(path.join(imagesDir.path, fileName));
      
      // 이미지 복사
      await imageFile.copy(savedImage.path);
      
      print('✅ 이미지 저장 완료: ${savedImage.path}');
      return savedImage.path;
    } catch (e) {
      print('❌ 이미지 저장 실패: $e');
      return null;
    }
  }

  /// 이미지 파일 삭제
  static Future<bool> deleteImage(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return true;
    
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
        print('✅ 이미지 삭제 완료: $imagePath');
        return true;
      }
      return true;
    } catch (e) {
      print('❌ 이미지 삭제 실패: $e');
      return false;
    }
  }

  /// 이미지 선택 옵션 표시 (갤러리/카메라)
  static Future<File?> showImageSourceDialog() async {
    // 이 메서드는 UI에서 호출되어야 하므로 여기서는 null을 반환
    // 실제 구현은 UI 컴포넌트에서 처리
    return null;
  }

  /// Assets에서 기본 아이콘 이미지 목록 가져오기 (동적으로 로드)
  static Future<List<String>> getDefaultIconUrls(String species) async {
    try {
      final speciesFolder = species.toLowerCase() == 'other' 
          ? 'others' 
          : '${species.toLowerCase()}s';
      
      print('🔍 Assets 폴더 경로 확인: $speciesFolder');
      
      // AssetManifest를 사용하여 동적으로 assets 파일 목록 가져오기
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestContent);
      
      // 해당 species 폴더의 모든 이미지 파일 필터링
      final assetPaths = manifestMap.keys
          .where((String key) => key.startsWith('assets/images/profile_icons/$speciesFolder/'))
          .where((String key) => key.endsWith('.png') || key.endsWith('.jpg') || key.endsWith('.jpeg'))
          .toList()
        ..sort(); // 파일명으로 정렬
      
      print('🔧 Assets 파일 목록: ${assetPaths.length}개');
      print('🔗 생성된 Assets 경로들: $assetPaths');
      
      return assetPaths;
    } catch (e) {
      print('❌ Assets 기본 아이콘 목록 가져오기 실패: $e');
      return [];
    }
  }

  /// 기본 아이콘 이미지 Assets 경로 가져오기
  static String getDefaultIconUrl(String species, String iconName) {
    try {
      // 확장자가 없으면 .png 추가
      String fileName = iconName;
      if (!iconName.toLowerCase().endsWith('.png') && 
          !iconName.toLowerCase().endsWith('.jpg') && 
          !iconName.toLowerCase().endsWith('.jpeg')) {
        fileName = '$iconName.png';
      }
      
      final assetPath = 'assets/images/profile_icons/${species.toLowerCase()}s/$fileName';
      
      print('🔗 Assets 아이콘 경로 생성: species=$species, iconName=$iconName, fileName=$fileName, path=$assetPath');
      
      return assetPath;
    } catch (e) {
      print('❌ Assets 기본 아이콘 경로 가져오기 실패: $e');
      return '';
    }
  }
}
