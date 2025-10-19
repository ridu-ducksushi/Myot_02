import 'package:flutter/material.dart';

/// 색상 관련 유틸리티 클래스
/// 단일 진실의 원칙을 적용하여 모든 색상 변환 로직을 중앙화
class ColorUtils {
  /// Color_X 문자열을 Color 객체로 변환
  /// ProfileImagePicker에서 사용하는 배경색 문자열을 Color로 변환
  static Color getBgColorFromString(String? bgColorString) {
    if (bgColorString == null) return Colors.grey;
    
    switch (bgColorString) {
      case 'Color_1':
        return const Color(0xFFFF6B6B); // 빨간색
      case 'Color_2':
        return const Color(0xFF4ECDC4); // 청록색
      case 'Color_3':
        return const Color(0xFF45B7D1); // 파란색
      case 'Color_4':
        return const Color(0xFF96CEB4); // 연두색
      case 'Color_5':
        return const Color(0xFFFECA57); // 노란색
      case 'Color_6':
        return const Color(0xFFFF9FF3); // 분홍색
      case 'Color_7':
        return const Color(0xFF54A0FF); // 하늘색
      case 'Color_8':
        return const Color(0xFF5F27CD); // 보라색
      default:
        return Colors.grey;
    }
  }
  
  /// Color 객체를 Color_X 문자열로 변환 (필요시 사용)
  static String? getStringFromBgColor(Color color) {
    if (color == const Color(0xFFFF6B6B)) return 'Color_1';
    if (color == const Color(0xFF4ECDC4)) return 'Color_2';
    if (color == const Color(0xFF45B7D1)) return 'Color_3';
    if (color == const Color(0xFF96CEB4)) return 'Color_4';
    if (color == const Color(0xFFFECA57)) return 'Color_5';
    if (color == const Color(0xFFFF9FF3)) return 'Color_6';
    if (color == const Color(0xFF54A0FF)) return 'Color_7';
    if (color == const Color(0xFF5F27CD)) return 'Color_8';
    return null;
  }
}
