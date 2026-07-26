import 'package:flutter_test/flutter_test.dart';
import 'package:vocatree/features/settings/data/services/backup_service.dart';
import 'package:vocatree/features/words/data/models/word.dart';
import 'package:vocatree/features/words/data/repositories/word_repository.dart';
import 'package:vocatree/features/review/data/repositories/review_repository.dart';
import 'package:vocatree/features/review/data/models/review_card.dart';

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
  });
}
