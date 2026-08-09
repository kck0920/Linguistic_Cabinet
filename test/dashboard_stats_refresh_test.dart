import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:linguistic_cabinet/features/achievements/data/achievement_service.dart';
import 'package:linguistic_cabinet/features/achievements/data/anniversary_service.dart';
import 'package:linguistic_cabinet/features/quiz/presentation/screens/meaning_quiz_screen.dart';
import 'package:linguistic_cabinet/features/review/presentation/screens/review_screen.dart';
import 'package:linguistic_cabinet/features/words/data/models/word.dart';
import 'package:linguistic_cabinet/features/words/presentation/screens/word_list_screen.dart';
import 'package:linguistic_cabinet/home/home_dashboard_screen.dart';
import 'package:linguistic_cabinet/home/home_screen.dart';
import 'helpers.dart';

final List<Word> _statsWords = [
  Word(id: 's1', english: 'apple', korean: '사과'),
  Word(id: 's2', english: 'banana', korean: '바나나'),
  Word(id: 's3', english: 'cherry', korean: '체리'),
  Word(id: 's4', english: 'date', korean: '대추'),
];

Future<void> _pumpDashboard(
  WidgetTester tester, {
  required FakeStatsRepository repo,
}) async {
  // 테스트 폰트 아티팩트(카탈로그 카드 overflow) 무시 — 테스트 본문 안에서 설치
  ignoreTestFontOverflow();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        reviewRepositoryProvider.overrideWithValue(repo),
        wordListProvider.overrideWith((ref) async => _statsWords),
        masterGardenBadgeProvider.overrideWith((ref) async => null),
        anniversaryTodayProvider.overrideWith((ref) async => false),
      ],
      child: const MaterialApp(home: HomeDashboardScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

/// pending Timer(다음 문제 전환용) 정리 — 화면 언마운트로 dispose를 유도한다.
Future<void> _disposeScreen(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
}

void main() {
  group('홈 탭 복귀 시 통계 갱신', () {
    testWidgets('복습 로그 증가 후 홈 탭 복귀 시 Reviews·Streak가 즉시 갱신된다',
        (tester) async {
      final repo = FakeStatsRepository(initialReviews: 7, streak: 3);
      await _pumpDashboard(tester, repo: repo);

      expect(find.text('7'), findsOneWidget);
      expect(find.text('3 Days'), findsOneWidget);

      // 퀴즈/복습 후 복습 로그가 늘었다고 가정 (logReview 호출로 카운트 증가)
      for (var i = 0; i < 5; i++) {
        await repo.logReview(
          wordId: 's${(i % 4) + 1}',
          isCorrect: true,
          studyMethod: 'flashcard',
        );
      }
      repo.streak = 4;

      // 홈 탭(0)에서 다른 탭으로 이동 후 다시 홈으로 복귀
      final container = ProviderScope.containerOf(
        tester.element(find.text('LEDGER SUMMARY')),
      );
      container.read(currentTabIndexProvider.notifier).state = 3; // Quiz
      await tester.pump();
      container.read(currentTabIndexProvider.notifier).state = 0; // Home 복귀
      await tester.pumpAndSettle();

      expect(find.text('12'), findsOneWidget);
      expect(find.text('4 Days'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('퀴즈 답변 → 홈 복귀 시 통계 갱신', () {
    testWidgets('퀴즈에서 답변 후 홈 대시보드의 Reviews가 반영된다', (tester) async {
      ignoreTestFontOverflow();
      final repo = FakeStatsRepository();
      final overrides = [
        reviewRepositoryProvider.overrideWithValue(repo),
        wordListProvider.overrideWith((ref) async => _statsWords),
        masterGardenBadgeProvider.overrideWith((ref) async => null),
        anniversaryTodayProvider.overrideWith((ref) async => false),
      ];

      // 1) 퀴즈 화면에서 1문제 답변 → 복습 로그 1건
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp(home: MeaningQuizScreen(words: _statsWords)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ElevatedButton).first);
      await tester.pump();
      expect(repo.loggedReviews, hasLength(1));

      // 2) 같은 ProviderScope 컨테이너를 유지한 채 홈 대시보드로 전환
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: const MaterialApp(home: HomeDashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // LEDGER SUMMARY의 Reviews = 1 (퀴즈 로그가 반영됨)
      expect(find.text('REVIEWS'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      // 3) 복습 로그가 더 쌓인 뒤 홈 탭 복귀 시 즉시 갱신 (탭 invalidate 검증)
      await repo.logReview(
        wordId: 's2',
        isCorrect: true,
        studyMethod: 'meaning_quiz',
      );
      final container = ProviderScope.containerOf(
        tester.element(find.text('LEDGER SUMMARY')),
      );
      container.read(currentTabIndexProvider.notifier).state = 3; // Quiz 탭
      await tester.pump();
      container.read(currentTabIndexProvider.notifier).state = 0; // Home 복귀
      await tester.pumpAndSettle();

      // Reviews = 2 (퀴즈 로그 1건 + 추가 로그 1건) — 홈 복귀 invalidate로 갱신됨
      expect(find.text('2'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _disposeScreen(tester);
    });
  });
}
