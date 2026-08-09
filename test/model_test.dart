import 'package:flutter_test/flutter_test.dart';
import 'package:linguistic_cabinet/features/words/data/models/word.dart';
import 'package:linguistic_cabinet/features/review/data/models/review_card.dart';

void main() {
  group('Word Model', () {
    test('creates with required fields only', () {
      final word = Word(english: 'hello', korean: '안녕');
      
      expect(word.english, 'hello');
      expect(word.korean, '안녕');
      expect(word.id, isNotEmpty);
      expect(word.tags, isEmpty);
      expect(word.difficulty, 3);
      expect(word.createdAt, isNotNull);
      expect(word.updatedAt, isNotNull);
    });

    test('creates with all fields', () {
      final now = DateTime.now();
      final word = Word(
        id: 'test-id',
        english: 'hello',
        korean: '안녕',
        exampleSentence: 'Hello world',
        pronunciation: '/həˈloʊ/',
        tags: ['greeting', 'basic'],
        difficulty: 2,
        memo: 'test memo',
        createdAt: now,
        updatedAt: now,
      );
      
      expect(word.id, 'test-id');
      expect(word.exampleSentence, 'Hello world');
      expect(word.pronunciation, '/həˈloʊ/');
      expect(word.tags, ['greeting', 'basic']);
      expect(word.difficulty, 2);
      expect(word.memo, 'test memo');
    });

    test('toMap/fromMap roundtrip', () {
      final original = Word(
        id: 'test-id',
        english: 'hello',
        korean: '안녕',
        exampleSentence: 'Hello world',
        pronunciation: '/həˈloʊ/',
        tags: ['greeting', 'basic'],
        difficulty: 2,
        memo: 'test memo',
      );
      
      final map = original.toMap();
      final restored = Word.fromMap(map);
      
      expect(restored.id, original.id);
      expect(restored.english, original.english);
      expect(restored.korean, original.korean);
      expect(restored.exampleSentence, original.exampleSentence);
      expect(restored.pronunciation, original.pronunciation);
      expect(restored.tags, original.tags);
      expect(restored.difficulty, original.difficulty);
      expect(restored.memo, original.memo);
    });

    test('toMap handles null optional fields', () {
      final word = Word(english: 'hello', korean: '안녕');
      final map = word.toMap();
      
      expect(map['example_sentence'], isNull);
      expect(map['pronunciation'], isNull);
      expect(map['memo'], isNull);
      expect(map['tags'], '');
    });

    test('fromMap handles empty tags string', () {
      final map = {
        'id': 'test-id',
        'english': 'hello',
        'korean': '안녕',
        'tags': '',
        'difficulty': 3,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      final word = Word.fromMap(map);
      expect(word.tags, isEmpty);
    });

    test('fromMap handles multiple tags', () {
      final map = {
        'id': 'test-id',
        'english': 'hello',
        'korean': '안녕',
        'tags': 'greeting,basic,common',
        'difficulty': 3,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      final word = Word.fromMap(map);
      expect(word.tags, ['greeting', 'basic', 'common']);
    });

    test('copyWith updates specified fields', () {
      final original = Word(english: 'hello', korean: '안녕');
      final copied = original.copyWith(english: 'world', korean: '세상');
      
      expect(copied.english, 'world');
      expect(copied.korean, '세상');
      expect(copied.id, original.id);
      expect(copied.difficulty, original.difficulty);
    });

    test('equality is based on id', () {
      final word1 = Word(id: 'same-id', english: 'hello', korean: '안녕');
      final word2 = Word(id: 'same-id', english: 'world', korean: '세상');
      final word3 = Word(id: 'different-id', english: 'hello', korean: '안녕');
      
      expect(word1, equals(word2));
      expect(word1, isNot(equals(word3)));
    });

    test('toString returns readable format', () {
      final word = Word(id: 'test-id', english: 'hello', korean: '안녕');
      expect(word.toString(), contains('hello'));
      expect(word.toString(), contains('안녕'));
    });

    test('adjustedDifficultyForReview lowers difficulty on correct answer', () {
      final word = Word(english: 'hello', korean: '안녕', difficulty: 3);
      expect(word.adjustedDifficultyForReview(isCorrect: true), 2);
    });

    test('adjustedDifficultyForReview raises difficulty on wrong answer', () {
      final word = Word(english: 'hello', korean: '안녕', difficulty: 3);
      expect(word.adjustedDifficultyForReview(isCorrect: false), 4);
    });

    test('adjustedDifficultyForReview clamps to 1..5 range', () {
      final easy = Word(english: 'hello', korean: '안녕', difficulty: 1);
      expect(easy.adjustedDifficultyForReview(isCorrect: true), 1);

      final hard = Word(english: 'hello', korean: '안녕', difficulty: 5);
      expect(hard.adjustedDifficultyForReview(isCorrect: false), 5);
    });

    test('adjustedDifficultyForReview reflects review result without mutating', () {
      final word = Word(english: 'hello', korean: '안녕', difficulty: 3);
      word.adjustedDifficultyForReview(isCorrect: true);
      expect(word.difficulty, 3); // 원본은 변경되지 않는다
    });

    test('adjustedDifficultyForReview crosses mastered boundary', () {
      // 난이도 ≤ 2가 MASTERED 기준 — difficulty 2에서 오답 시 3으로 이탈
      final mastered = Word(english: 'hello', korean: '안녕', difficulty: 2);
      expect(mastered.adjustedDifficultyForReview(isCorrect: false), 3);
    });
  });

  group('ReviewCard Model', () {
    test('creates with required fields', () {
      final now = DateTime.now();
      final card = ReviewCard(
        wordId: 'word-id',
        reviewMethod: ReviewMethod.linear,
        nextReviewDate: now,
      );
      
      expect(card.wordId, 'word-id');
      expect(card.reviewMethod, ReviewMethod.linear);
      expect(card.nextReviewDate, now);
      expect(card.id, isNotEmpty);
      expect(card.reviewCount, 0);
      expect(card.fixedIntervalDays, isNull);
    });

    test('linear schedule follows 1-3-7-30 pattern', () {
      expect(ReviewCard.linearSchedule, [1, 3, 7, 30]);
    });

    test('getNextReviewDate uses linear schedule', () {
      final card = ReviewCard(
        wordId: 'word-id',
        reviewMethod: ReviewMethod.linear,
        nextReviewDate: DateTime.now(),
        reviewCount: 0,
      );
      
      final nextDate = card.getNextReviewDate();
      final diff = nextDate.difference(DateTime.now()).inHours;
      expect(diff, greaterThanOrEqualTo(23)); // ~1 day (allow for test execution time)
      expect(diff, lessThanOrEqualTo(25));
    });

    test('getNextReviewDate uses fixed interval', () {
      final card = ReviewCard(
        wordId: 'word-id',
        reviewMethod: ReviewMethod.fixed,
        fixedIntervalDays: 7,
        nextReviewDate: DateTime.now(),
      );
      
      final nextDate = card.getNextReviewDate();
      final diff = nextDate.difference(DateTime.now()).inHours;
      expect(diff, greaterThanOrEqualTo(167)); // ~7 days
      expect(diff, lessThanOrEqualTo(169));
    });

    test('incrementReviewCount advances linear schedule', () {
      final card = ReviewCard(
        wordId: 'word-id',
        reviewMethod: ReviewMethod.linear,
        nextReviewDate: DateTime.now(),
        reviewCount: 0,
      );
      
      final nextCard = card.incrementReviewCount();
      expect(nextCard.reviewCount, 1);
      
      final nextDate = nextCard.getNextReviewDate();
      final diff = nextDate.difference(DateTime.now()).inHours;
      expect(diff, greaterThanOrEqualTo(71)); // ~3 days
      expect(diff, lessThanOrEqualTo(73));
    });

    test('isDueForReview returns true when past due', () {
      final card = ReviewCard(
        wordId: 'word-id',
        reviewMethod: ReviewMethod.linear,
        nextReviewDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      
      expect(card.isDueForReview, true);
    });

    test('isDueForReview returns false when not due', () {
      final card = ReviewCard(
        wordId: 'word-id',
        reviewMethod: ReviewMethod.linear,
        nextReviewDate: DateTime.now().add(const Duration(days: 1)),
      );
      
      expect(card.isDueForReview, false);
    });

    test('toMap/fromMap roundtrip', () {
      final now = DateTime.now();
      final nextReview = DateTime.now().add(const Duration(days: 3));
      final original = ReviewCard(
        id: 'test-id',
        wordId: 'word-id',
        reviewMethod: ReviewMethod.fixed,
        fixedIntervalDays: 7,
        nextReviewDate: nextReview,
        reviewCount: 2,
        createdAt: now,
      );
      
      final map = original.toMap();
      final restored = ReviewCard.fromMap(map);
      
      expect(restored.id, original.id);
      expect(restored.wordId, original.wordId);
      expect(restored.reviewMethod, original.reviewMethod);
      expect(restored.fixedIntervalDays, original.fixedIntervalDays);
      expect(restored.reviewCount, original.reviewCount);
    });

    test('toMap stores review method as string', () {
      final linearCard = ReviewCard(
        wordId: 'word-id',
        reviewMethod: ReviewMethod.linear,
        nextReviewDate: DateTime.now(),
      );
      final fixedCard = ReviewCard(
        wordId: 'word-id',
        reviewMethod: ReviewMethod.fixed,
        fixedIntervalDays: 7,
        nextReviewDate: DateTime.now(),
      );
      
      expect(linearCard.toMap()['review_method'], 'linear');
      expect(fixedCard.toMap()['review_method'], 'fixed');
    });

    test('equality is based on id', () {
      final card1 = ReviewCard(id: 'same-id', wordId: 'word-1', reviewMethod: ReviewMethod.linear, nextReviewDate: DateTime.now());
      final card2 = ReviewCard(id: 'same-id', wordId: 'word-2', reviewMethod: ReviewMethod.fixed, nextReviewDate: DateTime.now());
      final card3 = ReviewCard(id: 'different-id', wordId: 'word-1', reviewMethod: ReviewMethod.linear, nextReviewDate: DateTime.now());
      
      expect(card1, equals(card2));
      expect(card1, isNot(equals(card3)));
    });

    test('processReviewResult pushes nextReviewDate into the future', () {
      final card = ReviewCard(
        wordId: 'word-id',
        reviewMethod: ReviewMethod.linear,
        nextReviewDate: DateTime.now().subtract(const Duration(hours: 1)),
      );

      final updated = card.processReviewResult(isCorrect: true);
      expect(updated.isDueForReview, false);
      expect(updated.nextReviewDate.isAfter(DateTime.now()), true);
      expect(updated.reviewCount, 1);
    });
  });

  group('ReviewMethod Enum', () {
    test('has linear, fixed, and sm2 values', () {
      expect(ReviewMethod.values.length, 3);
      expect(ReviewMethod.values, contains(ReviewMethod.linear));
      expect(ReviewMethod.values, contains(ReviewMethod.fixed));
      expect(ReviewMethod.values, contains(ReviewMethod.sm2));
    });
  });
}
