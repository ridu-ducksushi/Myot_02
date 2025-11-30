/// 날짜 포맷팅 유틸리티
/// 
/// 날짜를 다양한 형식으로 변환하는 헬퍼 메서드를 제공합니다.
class DateUtils {
  DateUtils._();

  /// DateTime을 'YYYY-MM-DD' 형식의 문자열로 변환
  /// 
  /// [date] 변환할 날짜 (null이면 현재 날짜 사용)
  /// Returns 'YYYY-MM-DD' 형식의 문자열
  static String toDateKey(DateTime? date) {
    final targetDate = date ?? DateTime.now();
    return '${targetDate.year.toString().padLeft(4, '0')}-'
        '${targetDate.month.toString().padLeft(2, '0')}-'
        '${targetDate.day.toString().padLeft(2, '0')}';
  }
}

