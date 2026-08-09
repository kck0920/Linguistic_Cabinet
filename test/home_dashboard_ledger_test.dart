import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:linguistic_cabinet/features/review/data/repositories/review_repository.dart';
import 'package:linguistic_cabinet/features/review/presentation/screens/review_screen.dart';
import 'package:linguistic_cabinet/features/words/data/models/word.dart';
import 'package:linguistic_cabinet/features/words/presentation/screens/word_list_screen.dart';
import 'package:linguistic_cabinet/home/home_dashboard_screen.dart';
import 'helpers.dart';

/// LEDGER SUMMARY 검증용 가짜 리포: 통계·스트릭·설정을 메모리로 주입한다.
/// (실제 DB 접근 없이 화면이 읽는 값을 제어하기 위함)
class FakeLedgerRepository extends ReviewRepository {
  int reviews;
  int streak;
  int totalWords;
  int mastered;
  final Map<String, String> settings = {};

  FakeLedgerRepository({
    this.reviews = 0,
    this.streak = 0,
    this.totalWords = 0,
    this.mastered = 0,
  });

  @override
  Future<Map<String, dynamic>> getReviewStats() async => {
        'totalWords': totalWords,
        'dueForReview': 0,
        'totalReviews': reviews,
        'accuracy': reviews > 0 ? 100 : 0,
      };

  @override
  Future<int> getMasteredCount() async => mastered;

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

Future<void> _pumpDashboard(
  WidgetTester tester, {
  required List<Word> words,
  required FakeLedgerRepository repo,
}) async {
  // 테스트 폰트 아티팩트(카탈로그 카드 overflow) 무시 — 테스트 본문 안에서 설치
  ignoreTestFontOverflow();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        reviewRepositoryProvider.overrideWithValue(repo),
        wordListProvider.overrideWith((ref) async => words),
      ],
      child: const MaterialApp(home: HomeDashboardScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

/// difficulty <= 2인 단어만 숙달(Mastered)로 집계된다.
List<Word> _wordsWithDifficulty(List<int> difficulties) => List.generate(
      difficulties.length,
      (i) => Word(
        id: 'w$i',
        english: 'word$i',
        korean: '단어$i',
        difficulty: difficulties[i],
      ),
    );

void main() {
  group('LEDGER SUMMARY · 4개 타일 데이터', () {
    testWidgets('단어·숙달·스트릭·복습 수치가 올바르게 표시된다', (tester) async {
      // 총 5단어, difficulty <= 2 → 3단어 숙달
      final words = _wordsWithDifficulty([1, 1, 2, 4, 5]);
      final repo = FakeLedgerRepository(
        reviews: 7,
        streak: 3,
        totalWords: 5,
        mastered: 3,
      );

      await _pumpDashboard(tester, words: words, repo: repo);

      // 섹션 헤더
      expect(find.text('LEDGER SUMMARY'), findsOneWidget);
      // Collected = 전체 단어 수
      expect(find.text('COLLECTED'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      // Mastered = difficulty <= 2 개수 (분수 + 숙달 진행률)
      expect(find.text('MASTERED'), findsOneWidget);
      expect(find.text('3 / 5'), findsOneWidget);
      expect(find.text('60% 숙달'), findsOneWidget);
      // Streak = 현재 연속 학습 일수 (3일 → 복수형)
      expect(find.text('STREAK'), findsOneWidget);
      expect(find.text('3 Days'), findsOneWidget);
      // Reviews = 총 복습 횟수 (레포 주입값)
      expect(find.text('REVIEWS'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('스트릭 1일이면 단수 "1 Day"로 표시된다', (tester) async {
      final repo = FakeLedgerRepository(reviews: 1, streak: 1);

      await _pumpDashboard(tester, words: _wordsWithDifficulty([2]), repo: repo);

      expect(find.text('1 Day'), findsOneWidget);
      expect(find.text('1 Days'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('데이터가 없으면 0으로 표시된다', (tester) async {
      final repo = FakeLedgerRepository();

      await _pumpDashboard(tester, words: [], repo: repo);

      // Collected · Mastered · Reviews = 0 (3개 타일)
      expect(find.text('0'), findsNWidgets(3));
      // Streak = 0일 (복수형)
      expect(find.text('0 Days'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

}

