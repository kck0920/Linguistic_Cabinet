import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:linguistic_cabinet/features/quiz/presentation/screens/fill_blank_quiz_screen.dart';
import 'package:linguistic_cabinet/features/quiz/presentation/screens/meaning_quiz_screen.dart';
import 'package:linguistic_cabinet/features/quiz/presentation/screens/meaning_typing_screen.dart';
import 'package:linguistic_cabinet/features/quiz/presentation/screens/spelling_typing_screen.dart';
import 'package:linguistic_cabinet/features/review/data/repositories/review_repository.dart';
import 'package:linguistic_cabinet/features/review/presentation/screens/review_screen.dart';
import 'package:linguistic_cabinet/features/words/data/models/word.dart';

/// 퀴즈 답변·통계 검증용 가짜 리포.
/// logReview 호출을 캡처하고, 캡처된 횟수를 통계(totalReviews)로 반영한다.
class FakeQuizRepository extends ReviewRepository {
  final List<Map<String, dynamic>> loggedReviews = [];
  int _reviewCount = 0;
  int streak = 0;
  final Map<String, String> settings = {};

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
    // 퀴즈 화면이 호출하지만 DB 스케줄링은 검증 범위 밖 — no-op
  }

  @override
  Future<Map<String, dynamic>> getReviewStats() async => {
        'totalWords': 4,
        'dueForReview': 0,
        'totalReviews': _reviewCount,
        'accuracy': _reviewCount > 0 ? 100 : 0,
      };

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

final List<Word> _quizWords = [
  Word(id: 'q1', english: 'apple', korean: '사과'),
  Word(id: 'q2', english: 'banana', korean: '바나나'),
  Word(id: 'q3', english: 'cherry', korean: '체리'),
  Word(id: 'q4', english: 'date', korean: '대추'),
];

/// pending Timer(다음 문제 전환용) 정리 — 화면 언마운트로 dispose를 유도한다.
Future<void> _disposeScreen(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
}

void main() {
  group('퀴즈 화면 · 답변 시 logReview', () {
    testWidgets('뜻 맞추기(MeaningQuiz): 4지선다 탭 시 1회 기록된다', (tester) async {
      final repo = FakeQuizRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [reviewRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(home: MeaningQuizScreen(words: _quizWords)),
        ),
      );
      await tester.pumpAndSettle();

      // 아무 선택지나 탭 → 정답/오답 무관하게 기록되어야 한다.
      await tester.tap(find.byType(ElevatedButton).first);
      await tester.pump();

      expect(repo.loggedReviews, hasLength(1));
      final entry = repo.loggedReviews.first;
      expect(entry['studyMethod'], 'meaning_quiz');
      expect(entry['isCorrect'], isA<bool>());
      expect(
        _quizWords.map((w) => w.id),
        contains(entry['wordId']),
      );

      await _disposeScreen(tester);
    });

    testWidgets('빈칸 채우기(FillBlank): 입력 후 확인 시 1회 기록된다', (tester) async {
      final repo = FakeQuizRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [reviewRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(home: FillBlankQuizScreen(words: _quizWords)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'apple');
      await tester.pump();
      await tester.tap(find.text('확인'));
      await tester.pump();

      expect(repo.loggedReviews, hasLength(1));
      expect(repo.loggedReviews.first['studyMethod'], 'fill_blank');

      await _disposeScreen(tester);
    });

    testWidgets('뜻 타이핑(MeaningTyping): 입력 후 확인 시 1회 기록된다', (tester) async {
      final repo = FakeQuizRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [reviewRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(home: MeaningTypingScreen(words: _quizWords)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '사과');
      await tester.pump();
      await tester.tap(find.text('확인'));
      await tester.pump();

      expect(repo.loggedReviews, hasLength(1));
      expect(repo.loggedReviews.first['studyMethod'], 'meaning_typing');

      await _disposeScreen(tester);
    });

    testWidgets('철자 타이핑(SpellingTyping): 입력 후 확인 시 1회 기록된다', (tester) async {
      final repo = FakeQuizRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [reviewRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(home: SpellingTypingScreen(words: _quizWords)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'apple');
      await tester.pump();
      await tester.tap(find.text('확인'));
      await tester.pump();

      expect(repo.loggedReviews, hasLength(1));
      expect(repo.loggedReviews.first['studyMethod'], 'spelling_typing');

      await _disposeScreen(tester);
    });
  });

}

