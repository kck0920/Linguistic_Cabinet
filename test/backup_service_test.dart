import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:linguistic_cabinet/features/settings/data/services/backup_service.dart';
import 'package:linguistic_cabinet/features/words/data/models/word.dart';
import 'package:linguistic_cabinet/features/words/data/repositories/word_repository.dart';
import 'package:linguistic_cabinet/features/review/data/repositories/review_repository.dart';
import 'package:linguistic_cabinet/features/review/data/models/review_card.dart';

class MockWordRepository extends WordRepository {
  final List<Word> _db = [];

  @override
  Future<List<Word>> getAllWords() async {
    return List.from(_db);
  }

  @override
  Future<void> insertWords(List<Word> words) async {
    _db.addAll(words);
  }

  @override
  Future<void> updateWord(Word word) async {
    final index = _db.indexWhere((w) => w.id == word.id);
    if (index != -1) {
      _db[index] = word;
    }
  }
}

class MockReviewRepository extends ReviewRepository {
  final Map<String, String> _settings = {};

  @override
  Future<String?> getSetting(String key) async {
    return _settings[key];
  }

  @override
  Future<void> setSetting(String key, String value) async {
    _settings[key] = value;
  }

  @override
  Future<void> insertReviewCard(ReviewCard card) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('BackupService Tests', () {
    late MockWordRepository mockRepo;
    late MockReviewRepository mockReviewRepo;
    late BackupService backupService;

    setUp(() {
      mockRepo = MockWordRepository();
      mockReviewRepo = MockReviewRepository();
      backupService = BackupService(mockRepo, mockReviewRepo);
    });

    test('importBackupFromString inserts new words', () async {
      const jsonStr = '''
      [
        {
          "id": "1",
          "english": "apple",
          "korean": "사과",
          "difficulty": 3,
          "created_at": "2026-07-14T00:00:00.000"
        },
        {
          "id": "2",
          "english": "banana",
          "korean": "바나나",
          "difficulty": 2,
          "created_at": "2026-07-14T00:00:00.000"
        }
      ]
      ''';

      final result = await backupService.importBackupFromString(jsonStr);

      expect(result.importedCount, 2);
      expect(result.updatedCount, 0);

      final words = await mockRepo.getAllWords();
      expect(words.length, 2);
      expect(words[0].english, 'apple');
      expect(words[1].english, 'banana');
    });

    test('importBackupFromString updates existing words matching by English case-insensitively', () async {
      // Setup existing word
      final existingWord = Word(
        id: 'existing-id',
        english: 'Apple',
        korean: '사과',
        difficulty: 1,
      );
      await mockRepo.insertWords([existingWord]);

      const jsonStr = '''
      [
        {
          "id": "new-id-ignored",
          "english": "apple",
          "korean": "맛있는 사과",
          "difficulty": 3
        }
      ]
      ''';

      final result = await backupService.importBackupFromString(jsonStr);

      expect(result.importedCount, 0);
      expect(result.updatedCount, 1);

      final words = await mockRepo.getAllWords();
      expect(words.length, 1);
      expect(words[0].id, 'existing-id'); // Keep existing ID
      expect(words[0].english, 'apple');
      expect(words[0].korean, '맛있는 사과'); // Updated Korean definition
      expect(words[0].difficulty, 3); // Updated difficulty
    });

    test('importBackupFromString throws FormatException on invalid json structure', () async {
      const jsonStr = '{"key": "not a list"}';

      expect(
        () => backupService.importBackupFromString(jsonStr),
        throwsFormatException,
      );
    });

    test('importBackupFromString skips invalid items with missing English or Korean', () async {
      const jsonStr = '''
      [
        {
          "english": "grape"
        },
        {
          "korean": "멜론"
        },
        {
          "english": "orange",
          "korean": "오렌지"
        }
      ]
      ''';

      final result = await backupService.importBackupFromString(jsonStr);

      expect(result.importedCount, 1);
      expect(result.updatedCount, 0);

      final words = await mockRepo.getAllWords();
      expect(words.length, 1);
      expect(words[0].english, 'orange');
    });

    // ── 타임스탬프 보존 (createdAt 유실 회귀) ──────────────────────────

    test('created_at 없는 백업은 기존 단어의 createdAt을 보존한다', () async {
      // 버그 회귀: 백업에 created_at이 없으면 생성자 기본값(DateTime.now())으로
      // 덮어써져 등록일이 사라지고 카탈로그 번호까지 틀어졌다.
      final originalCreatedAt = DateTime(2024, 3, 15, 10, 30);
      await mockRepo.insertWords([
        Word(
          id: 'existing-id',
          english: 'apple',
          korean: '사과',
          difficulty: 1,
          createdAt: originalCreatedAt,
        ),
      ]);

      const jsonStr = '''
      [
        { "english": "apple", "korean": "맛있는 사과", "difficulty": 2 }
      ]
      ''';

      final result = await backupService.importBackupFromString(jsonStr);
      expect(result.updatedCount, 1);

      final words = await mockRepo.getAllWords();
      expect(words.length, 1);
      expect(words[0].korean, '맛있는 사과', reason: '본문은 갱신되어야 한다');
      expect(
        words[0].createdAt,
        originalCreatedAt,
        reason: '백업에 created_at이 없어도 기존 등록일은 보존되어야 한다',
      );
    });

    test('created_at이 있는 백업은 신규 단어의 등록일로 사용된다', () async {
      const jsonStr = '''
      [
        {
          "english": "cherry",
          "korean": "체리",
          "difficulty": 3,
          "created_at": "2020-06-01T12:00:00.000"
        }
      ]
      ''';

      await backupService.importBackupFromString(jsonStr);

      final words = await mockRepo.getAllWords();
      expect(words.length, 1);
      expect(words[0].createdAt, DateTime(2020, 6, 1, 12));
    });

    test('updated_at이 백업에 있으면 원본 값을 보존한다', () async {
      const jsonStr = '''
      [
        {
          "english": "date",
          "korean": "대추",
          "difficulty": 3,
          "created_at": "2021-01-01T00:00:00.000",
          "updated_at": "2021-05-05T09:15:00.000"
        }
      ]
      ''';

      await backupService.importBackupFromString(jsonStr);

      final words = await mockRepo.getAllWords();
      expect(words[0].updatedAt, DateTime(2021, 5, 5, 9, 15));
    });

    test('형식이 깨진 created_at은 등록일만 폴백하고 단어는 유실하지 않는다', () async {
      // 버그 회귀: DateTime.parse는 고장난 값에 FormatException을 던져
      // 백업 전체가 실패했다. 이제는 그 항목만 등록 시각으로 폴백하고
      // 나머지 항목은 정상 처리된다(사용자 단어 유실이 더 나쁜 손해).
      const jsonStr = '''
      [
        {
          "english": "broken",
          "korean": "깨짐",
          "created_at": "not-a-date"
        },
        {
          "english": "valid",
          "korean": "정상",
          "created_at": "2020-06-01T12:00:00.000"
        }
      ]
      ''';

      final result = await backupService.importBackupFromString(jsonStr);

      expect(result.importedCount, 2, reason: '깨진 항목도 단어는 보존되어야 한다');
      final words = await mockRepo.getAllWords();
      expect(words.length, 2);
      expect(words.map((w) => w.english), containsAll(['broken', 'valid']));

      final valid = words.firstWhere((w) => w.english == 'valid');
      expect(valid.createdAt, DateTime(2020, 6, 1, 12));
    });

    test('예상치 못한 타입의 필드는 크래시 없이 기본값으로 폴백된다', () async {
      final jsonStr = jsonEncode([
        {
          'english': 'weird',
          'korean': '이상',
          'difficulty': 'not-an-int',
          'memo': 123,
          'example_sentence': ['list', 'not', 'string'],
          'created_at': 20200101,
        },
      ]);

      final result = await backupService.importBackupFromString(jsonStr);

      expect(result.importedCount, 1);
      final words = await mockRepo.getAllWords();
      expect(words.length, 1);
      expect(words[0].difficulty, 3, reason: '난이도 기본값 폴백');
      expect(words[0].memo, isNull, reason: '잘못된 타입은 null로 무시');
      expect(words[0].exampleSentence, isNull);
      expect(words[0].createdAt, isNotNull, reason: '생성 시각으로 폴백되어야 한다');
    });
  });
}
