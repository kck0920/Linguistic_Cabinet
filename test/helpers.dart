import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:linguistic_cabinet/features/review/data/repositories/review_repository.dart';

/// 통계·로그 검증 공용 가짜 리포.
/// logReview 호출을 캡처하고, 캡처된 횟수를 통계(totalReviews)로 반영한다.
/// 초기값([initialReviews]/[streak])으로 '이미 쌓인 로그' 상황을 시뮬레이션할 수
/// 있다. `_reviewCount`는 logReview 호출로만 증가하므로 수동 동기화가 필요 없다.
class FakeStatsRepository extends ReviewRepository {
  final List<Map<String, dynamic>> loggedReviews = [];
  final List<Map<String, dynamic>> processedReviews = [];
  int _reviewCount;
  int streak;
  final Map<String, String> settings = {};

  FakeStatsRepository({int initialReviews = 0, this.streak = 0})
      : _reviewCount = initialReviews;

  @override
  Future<void> logReview({
    required String wordId,
    required bool isCorrect,
    String? studyMethod,
    int? durationMs,
    String? answerType,
  }) async {
    loggedReviews.add({
      'wordId': wordId,
      'isCorrect': isCorrect,
      'studyMethod': studyMethod,
    });
    _reviewCount++;
  }

  @override
  Future<void> processReviewResult({
    required String wordId,
    required bool isCorrect,
    int quality = 4,
  }) async {
    // DB 스케줄링은 검증 범위 밖 — 호출만 캡처한다.
    processedReviews.add({
      'wordId': wordId,
      'isCorrect': isCorrect,
      'quality': quality,
    });
  }

  @override
  Future<Map<String, dynamic>> getReviewStats() async => {
        'totalWords': 4,
        'dueForReview': 0,
        'totalReviews': _reviewCount,
        'accuracy': _reviewCount > 0 ? 100 : 0,
      };

  @override
  Future<int> getMasteredCount() async => 0;

  @override
  Future<int> getCurrentStreakDays() async => streak;

  @override
  Future<Map<int, int>> getMonthlyStudyDayCounts() async => {};

  @override
  Future<List<int>> getStreakGridData({int days = 182}) async =>
      List<int>.filled(days, 0);

  @override
  Future<String?> getSetting(String key) async => settings[key];

  @override
  Future<void> setSetting(String key, String value) async {
    settings[key] = value;
  }

  @override
  Future<Map<String, String>> getSettings(List<String> keys) async => {
        for (final k in keys)
          if (settings[k] != null) k: settings[k]!,
      };
}

/// 테스트 폰트(Ahem)는 실제 글꼴보다 글자 폭이 넓어, 홈 대시보드의 카탈로그
/// 카드(cabinet_widgets.dart, LEDGER SUMMARY와 무관한 위젯)에서 RenderFlex
/// overflow가 발생한다. 실기기 폰트에서는 발생하지 않는 테스트 환경 한정
/// 아티팩트이므로 카탈로그 카드 범위로 한정해 무시한다.
///
/// flutter_test 바인딩이 테스트 본문 실행 시점에 FlutterError.onError를 자체
/// 핸들러로 설치하므로, 반드시 테스트 본문(또는 본문 내부에서 호출되는 헬퍼)
/// 안에서 호출해야 한다 (setUp에서는 바인딩 핸들러에 덮어써진다).
void ignoreTestFontOverflow() {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.toString();
    if (text.contains('overflowed') && text.contains('cabinet_widgets.dart')) {
      return;
    }
    original?.call(details);
  };
  addTearDown(() {
    FlutterError.onError = original;
  });
}
