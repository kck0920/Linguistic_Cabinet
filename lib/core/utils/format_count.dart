/// 천 단위 쉼표 포맷 공용 헬퍼 (1,200 / 2,000단어).
/// 업적 컬렉션·상세 화면·배지 카드가 함께 사용한다 (단일 진실 원천).
String formatCount(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}
