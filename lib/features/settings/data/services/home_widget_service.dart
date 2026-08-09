// ignore_for_file: prefer_initializing_formals
// (_helper는 파라미터명·필드명이 달라 initializing formal로 대체할 수 없다)

import '../../../../core/utils/home_widget_helper.dart';
import '../../../review/data/repositories/review_repository.dart';

/// 홈 화면 위젯 데이터 갱신 서비스.
/// 앱의 학습 상태(오늘 복습 대상 수·숙달 단어 수)를 스냅샷으로 저장하고
/// 위젯 갱신을 요청한다. 미지원 플랫폼(웹·Windows/Linux)은 내부에서 무시된다.
class HomeWidgetService {
  final ReviewRepository _reviewRepository;
  final HomeWidgetHelper _helper;

  HomeWidgetService(
    this._reviewRepository, {
    HomeWidgetHelper helper = const HomeWidgetHelper(),
  }) : _helper = helper;

  /// 위젯이 표시할 스냅샷을 계산·저장하고 갱신을 요청한다.
  /// 모든 실패는 무시 (위젯은 보조 기능 — 앱 동작을 막지 않는다).
  Future<void> refreshWidgetData() async {
    try {
      if (!_helper.isSupported) return;

      final stats = await _reviewRepository.getReviewStats();
      final masteredCount = await _reviewRepository.getMasteredCount();
      final dueCount = stats['dueForReview'] as int? ?? 0;

      await _helper.saveData(dueCount: dueCount, masteredCount: masteredCount);
      await _helper.update();
    } catch (_) {
      // 플러그인 미지원·예외는 무시 (앱 시작 시 즉시 알림 등 대체 경로가 동작)
    }
  }
}
