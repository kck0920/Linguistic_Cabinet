import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:linguistic_cabinet/features/matching/presentation/screens/grid_matching_screen.dart';
import 'package:linguistic_cabinet/features/matching/presentation/screens/word_matching_screen.dart';
import 'package:linguistic_cabinet/features/review/presentation/screens/review_screen.dart';
import 'package:linguistic_cabinet/features/words/data/models/word.dart';
import 'helpers.dart';

/// 매칭 게임에 사용할 4단어 (각 화면이 4쌍 = 8장/8타일로 게임을 구성).
final List<Word> _gameWords = [
  Word(id: 'w1', english: 'apple', korean: '사과'),
  Word(id: 'w2', english: 'banana', korean: '바나나'),
  Word(id: 'w3', english: 'cherry', korean: '체리'),
  Word(id: 'w4', english: 'date', korean: '대추'),
];

/// 게임 보드 안의 카드/타일(GestureDetector)들을 순서대로 가져온다.
Finder _gameTiles(WidgetTester tester) => find.descendant(
      of: find.byType(GridView),
      matching: find.byType(GestureDetector),
    );

/// i번째 타일이 매칭 완료 상태(체크 아이콘)인지 확인한다.
bool _isMatched(WidgetTester tester, Finder tiles, int i) =>
    find
        .descendant(
          of: tiles.at(i),
          matching: find.byIcon(Icons.check_circle),
        )
        .evaluate()
        .isNotEmpty;

/// brute-force 매칭: 첫 타일을 뒤집고, 짝이 되는 타일을 순서대로 시도한다.
Future<void> _completeMatchingGame(WidgetTester tester) async {
  final tiles = _gameTiles(tester);
  final count = tiles.evaluate().length;

  for (var i = 0; i < count; i++) {
    if (_isMatched(tester, tiles, i)) continue;

    await tester.tap(tiles.at(i));
    await tester.pump(const Duration(milliseconds: 400)); // reveal 애니메이션

    for (var j = i + 1; j < count; j++) {
      if (_isMatched(tester, tiles, j)) continue;

      await tester.tap(tiles.at(j));
      await tester.pump(const Duration(milliseconds: 100));

      if (_isMatched(tester, tiles, i)) {
        // 짝 발견 → 매칭 확정 애니메이션 대기 후 다음 타일로
        await tester.pump(const Duration(milliseconds: 400));
        break;
      }

      // 매칭 실패: 흔들림/숨김 애니메이션이 끝날 때까지 기다린 뒤
      // 첫 타일을 다시 뒤집는다.
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      await tester.tap(tiles.at(i));
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  // 마지막 매칭 후 완료 다이얼로그(300ms 지연)가 뜨도록 정리
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

/// 매칭 보드(2열 그리드, 카드 4행 이상)가 모두 보이도록 테스트 화면을 키운다.
void _useLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  group('WordMatchingScreen · 완료 시 logReview·일정 반영', () {
    testWidgets('모든 쌍 매칭 완료 시 각 단어가 1회씩 기록된다', (tester) async {
      _useLargeSurface(tester);
      final repo = FakeStatsRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [reviewRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(home: WordMatchingScreen(words: _gameWords)),
        ),
      );
      await tester.pumpAndSettle();

      // 게임 자동 완료
      await _completeMatchingGame(tester);

      // 완료 다이얼로그 표시
      expect(find.text('매칭 완료!'), findsOneWidget);

      // 4단어 × 1회씩 기록
      expect(repo.loggedReviews.length, 4);
      final loggedIds = repo.loggedReviews.map((e) => e['wordId']).toSet();
      expect(loggedIds, {'w1', 'w2', 'w3', 'w4'});
      for (final entry in repo.loggedReviews) {
        expect(entry['isCorrect'], true);
        expect(entry['studyMethod'], 'word_matching');
      }
      // 퀴즈와 동일하게 각 단어의 복습 일정(processReviewResult)도 갱신된다
      expect(repo.processedReviews.length, 4);
      final processedIds = repo.processedReviews.map((e) => e['wordId']).toSet();
      expect(processedIds, {'w1', 'w2', 'w3', 'w4'});
      for (final entry in repo.processedReviews) {
        expect(entry['isCorrect'], true);
        expect(entry['quality'], 4); // 퀴즈와 동일한 기본 품질
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('GridMatchingScreen · 완료 시 logReview·일정 반영', () {
    testWidgets('모든 쌍 매칭 완료 시 각 단어가 1회씩 기록된다', (tester) async {
      _useLargeSurface(tester);
      final repo = FakeStatsRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [reviewRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(home: GridMatchingScreen(words: _gameWords)),
        ),
      );
      await tester.pumpAndSettle();

      // 게임 자동 완료
      await _completeMatchingGame(tester);

      expect(find.text('매칭 완료!'), findsOneWidget);

      expect(repo.loggedReviews.length, 4);
      final loggedIds = repo.loggedReviews.map((e) => e['wordId']).toSet();
      expect(loggedIds, {'w1', 'w2', 'w3', 'w4'});
      for (final entry in repo.loggedReviews) {
        expect(entry['isCorrect'], true);
        expect(entry['studyMethod'], 'grid_matching');
      }
      // 퀴즈와 동일하게 각 단어의 복습 일정(processReviewResult)도 갱신된다
      expect(repo.processedReviews.length, 4);
      final processedIds = repo.processedReviews.map((e) => e['wordId']).toSet();
      expect(processedIds, {'w1', 'w2', 'w3', 'w4'});
      for (final entry in repo.processedReviews) {
        expect(entry['isCorrect'], true);
        expect(entry['quality'], 4); // 퀴즈와 동일한 기본 품질
      }
      expect(tester.takeException(), isNull);
    });
  });
}
