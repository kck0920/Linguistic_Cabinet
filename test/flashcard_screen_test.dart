import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocatree/features/words/data/models/word.dart';
import 'package:vocatree/features/review/presentation/screens/flashcard_screen.dart';
import 'package:vocatree/features/review/presentation/screens/review_screen.dart';
import 'package:vocatree/features/review/data/repositories/review_repository.dart';

class FakeReviewRepository extends ReviewRepository {
  final List<Map<String, dynamic>> loggedReviews = [];

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
      'durationMs': durationMs,
      'answerType': answerType,
    });
  }

  @override
  Future<void> updateReviewCardWithSM2({required String wordId, required int quality}) async {
    // No-op for tests
  }
}

void main() {
  testWidgets('FlashcardScreen navigates to next card and resets flip controller', (WidgetTester tester) async {
    final words = [
      Word(id: '1', english: 'apple', korean: '사과'),
      Word(id: '2', english: 'banana', korean: '바나나'),
    ];

    final fakeRepo = FakeReviewRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reviewRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: MaterialApp(
          home: FlashcardScreen(words: words),
        ),
      ),
    );

    // Initial state: Card 1 (apple)
    expect(find.text('apple'), findsOneWidget);
    expect(find.textContaining('1 / 2'), findsOneWidget);

    // Click "뒤집기" (Flip) to show the back of the card
    await tester.tap(find.textContaining('뒤집기'));
    await tester.pumpAndSettle();

    // Check that we see the back card contents
    expect(find.text('사과'), findsOneWidget);

    // Tap "알았다" to go to the next card
    await tester.tap(find.textContaining('알았다'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Now it should show Card 2 (banana)
    expect(find.text('banana'), findsOneWidget);
    expect(find.textContaining('2 / 2'), findsOneWidget);
  });
}
