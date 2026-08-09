/// 웹·미지원 플랫폼용 홈 위젯 헬퍼 — 아무 동작도 하지 않는다.
class HomeWidgetHelper {
  const HomeWidgetHelper();

  bool get isSupported => false;

  Future<void> saveData({
    required int dueCount,
    required int masteredCount,
  }) async {
    // 미지원 — no-op
  }

  Future<void> update() async {
    // 미지원 — no-op
  }
}
