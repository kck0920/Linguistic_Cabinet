import 'package:flutter_test/flutter_test.dart';

import 'package:linguistic_cabinet/core/utils/home_widget_helper.dart';
import 'package:linguistic_cabinet/features/review/data/repositories/review_repository.dart';
import 'package:linguistic_cabinet/features/settings/data/services/home_widget_service.dart';

/// 홈 위젯 헬퍼 가짜 — saveData/update 호출을 캡처한다.
class FakeHomeWidgetHelper extends HomeWidgetHelper {
  final bool supported;
  final Object? saveError;
  int dueCount = -1;
  int masteredCount = -1;
  int updateCalls = 0;
  bool saveCalled = false;

  FakeHomeWidgetHelper({this.supported = true, this.saveError});

  @override
  bool get isSupported => supported;

  @override
  Future<void> saveData({
    required int dueCount,
    required int masteredCount,
  }) async {
    if (saveError != null) throw saveError!;
    saveCalled = true;
    this.dueCount = dueCount;
    this.masteredCount = masteredCount;
  }

  @override
  Future<void> update() async {
    updateCalls++;
  }
}

/// 리포 가짜 — 위젯 스냅샷 계산에 쓰이는 통계만 오버라이드.
class FakeWidgetRepository extends ReviewRepository {
  int due;
  int mastered;

  FakeWidgetRepository({this.due = 0, this.mastered = 0});

  @override
  Future<Map<String, dynamic>> getReviewStats() async => {
        'totalWords': 4,
        'dueForReview': due,
        'totalReviews': 0,
        'accuracy': 0,
      };

  @override
  Future<int> getMasteredCount() async => mastered;
}

void main() {
  group('HomeWidgetService.refreshWidgetData', () {
    test('복습 대상 수·숙달 수를 스냅샷으로 저장하고 위젯을 갱신한다', () async {
      final helper = FakeHomeWidgetHelper();
      final service = HomeWidgetService(
        FakeWidgetRepository(due: 7, mastered: 3),
        helper: helper,
      );

      await service.refreshWidgetData();

      expect(helper.saveCalled, isTrue);
      expect(helper.dueCount, 7);
      expect(helper.masteredCount, 3);
      expect(helper.updateCalls, 1);
    });

    test('미지원 플랫폼(웹·데스크톱)에서는 아무 동작도 하지 않는다', () async {
      final helper = FakeHomeWidgetHelper(supported: false);
      final service = HomeWidgetService(
        FakeWidgetRepository(due: 7, mastered: 3),
        helper: helper,
      );

      await service.refreshWidgetData();

      expect(helper.saveCalled, isFalse);
      expect(helper.updateCalls, 0);
    });

    test('저장 실패(플러그인 미지원 등)는 예외를 전파하지 않는다', () async {
      final helper = FakeHomeWidgetHelper(saveError: StateError('no plugin'));
      final service = HomeWidgetService(
        FakeWidgetRepository(due: 7, mastered: 3),
        helper: helper,
      );

      await service.refreshWidgetData();

      // 예외가 전파되지 않아야 한다 — 이 라인에 도달하면 통과.
      expect(true, isTrue);
    });

    test('빈 통계(0)도 안전하게 저장한다', () async {
      final helper = FakeHomeWidgetHelper();
      final service = HomeWidgetService(
        FakeWidgetRepository(due: 0, mastered: 0),
        helper: helper,
      );

      await service.refreshWidgetData();

      expect(helper.dueCount, 0);
      expect(helper.masteredCount, 0);
      expect(helper.updateCalls, 1);
    });
  });
}
