import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:linguistic_cabinet/features/achievements/data/achievement_evaluator.dart';
import 'package:linguistic_cabinet/features/achievements/presentation/achievement_toast_overlay.dart';
import 'package:linguistic_cabinet/features/review/data/repositories/review_repository.dart';
import 'package:linguistic_cabinet/features/review/presentation/screens/review_screen.dart';

/// 수여 평가용 가짜 리포: [wordCount]만큼 단어가 있다고 보고한다.
class FakeAwardingRepo extends ReviewRepository {
  final Map<String, String> settings = {};
  int wordCount = 0;

  @override
  Future<String?> getSetting(String key) async => settings[key];

  @override
  Future<void> setSetting(String key, String value) async {
    settings[key] = value;
  }

  @override
  Future<Map<String, dynamic>> getReviewStats() async => {
        'totalWords': wordCount,
        'dueForReview': 0,
        'totalReviews': 0,
        'accuracy': 0,
      };

  @override
  Future<int> getCurrentStreakDays() async => 0;

  @override
  Future<Map<int, int>> getMonthlyStudyDayCounts() async => {};
}

Widget _wrap(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      home: Scaffold(
        body: Stack(children: [CabinetAchievementToastOverlay()]),
      ),
    ),
  );
}

void main() {
  testWidgets('평가 후 해금된 업적 토스트가 표시되고 시간이 지나 사라진다', (tester) async {
    final container = ProviderContainer(
      overrides: [
        reviewRepositoryProvider.overrideWithValue(
          FakeAwardingRepo()..wordCount = 1500, // 수집 업적 3개 해금
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(container));
    await tester.pump();

    // 초기에는 토스트 없음
    expect(find.text('ACHIEVEMENT UNLOCKED'), findsNothing);

    // 복습 완료 등 이벤트로 평가 → 해금 3개 → 토스트 표시
    await container.read(achievementEvaluatorProvider).evaluateNow();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('ACHIEVEMENT UNLOCKED'), findsNWidgets(3));
    expect(find.text('First Word 달성!'), findsOneWidget);
    expect(find.text('Collector 100 달성!'), findsOneWidget);
    expect(find.text('Collector 1000 달성!'), findsOneWidget);
    expect(find.text('NEW!'), findsNWidgets(3));
    expect(tester.takeException(), isNull);

    // 3초 재생 완료 후 사라진다
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('달성!'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('해금된 업적이 없으면 토스트가 표시되지 않는다', (tester) async {
    final container = ProviderContainer(
      overrides: [
        reviewRepositoryProvider.overrideWithValue(FakeAwardingRepo()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(container));
    await tester.pump();

    await container.read(achievementEvaluatorProvider).evaluateNow();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('ACHIEVEMENT UNLOCKED'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('쿨다운 구간의 재평가는 방출하지 않는다', (tester) async {
    final container = ProviderContainer(
      overrides: [
        reviewRepositoryProvider.overrideWithValue(
          FakeAwardingRepo()..wordCount = 1500,
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(container));
    await tester.pump();

    final evaluator = container.read(achievementEvaluatorProvider);

    // 첫 평가: 해금 3개
    final first = await evaluator.evaluateNow();
    await tester.pump(const Duration(milliseconds: 400));
    expect(first.length, 3);
    expect(find.text('ACHIEVEMENT UNLOCKED'), findsNWidgets(3));

    // 3초 쿨다운 내 재평가: 빈 목록 + 추가 토스트 없음
    final second = await evaluator.evaluateNow();
    await tester.pump(const Duration(milliseconds: 400));
    expect(second, isEmpty);
    expect(find.text('ACHIEVEMENT UNLOCKED'), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });
}
