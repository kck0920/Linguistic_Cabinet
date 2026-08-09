import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:linguistic_cabinet/features/review/data/models/review_card.dart';
import 'package:linguistic_cabinet/features/review/data/repositories/review_repository.dart';
import 'package:linguistic_cabinet/features/words/data/models/word.dart';
import 'package:linguistic_cabinet/shared/services/database_service.dart';

/// processReviewResult(복습 결과)가 words 테이블의 difficulty에 자동 반영되는지
/// 검증한다. 정책: 정답 -1, 오답 +1, 1~5 범위 유지 (항상 적용, 토글 없음).
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<Database> createDb() async {
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    // 실제 스키마 중 processReviewResult가 접근하는 테이블만 최소 구성
    await db.execute('''
      CREATE TABLE words (
        id TEXT PRIMARY KEY,
        english TEXT NOT NULL,
        korean TEXT NOT NULL,
        example_sentence TEXT,
        pronunciation TEXT,
        tags TEXT,
        difficulty INTEGER DEFAULT 3,
        memo TEXT,
        image_path TEXT,
        dictionary_url TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE review_cards (
        id TEXT PRIMARY KEY,
        word_id TEXT NOT NULL,
        review_method TEXT NOT NULL,
        override_method TEXT,
        fixed_interval_days INTEGER,
        next_review_date TEXT NOT NULL,
        review_count INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        easiness_factor REAL DEFAULT 2.5,
        interval INTEGER DEFAULT 0,
        repetition INTEGER DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    return db;
  }

  Future<void> setSetting(Database db, String key, String value) async {
    await db.insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Word> insertWord(Database db, {int difficulty = 3}) async {
    final word = Word(english: 'hello', korean: '안녕', difficulty: difficulty);
    await db.insert('words', word.toMap());
    return word;
  }

  Future<void> insertCard(Database db, String wordId) async {
    final card = ReviewCard(
      wordId: wordId,
      reviewMethod: ReviewMethod.linear,
      nextReviewDate: DateTime.now().subtract(const Duration(days: 1)),
    );
    await db.insert('review_cards', card.toMap());
  }

  Future<int> fetchDifficulty(Database db, String wordId) async {
    final maps = await db.query('words', where: 'id = ?', whereArgs: [wordId]);
    return maps.first['difficulty'] as int;
  }

  test('정답 복습은 난이도를 1 낮춘다 (3 → 2)', () async {
    final db = await createDb();
    DatabaseService.setTestDatabase(db);
    try {
      final word = await insertWord(db, difficulty: 3);
      await insertCard(db, word.id);

      final repo = ReviewRepository();
      await repo.processReviewResult(wordId: word.id, isCorrect: true);

      expect(await fetchDifficulty(db, word.id), 2);
    } finally {
      DatabaseService.clearTestDatabase();
      await db.close();
    }
  });

  test('오답 복습은 난이도를 1 올린다 (3 → 4)', () async {
    final db = await createDb();
    DatabaseService.setTestDatabase(db);
    try {
      final word = await insertWord(db, difficulty: 3);
      await insertCard(db, word.id);

      final repo = ReviewRepository();
      await repo.processReviewResult(wordId: word.id, isCorrect: false);

      expect(await fetchDifficulty(db, word.id), 4);
    } finally {
      DatabaseService.clearTestDatabase();
      await db.close();
    }
  });

  test('연속 정답으로 MASTERED(난이도 ≤ 2)에 진입한다 (3 → 2 → 1)', () async {
    final db = await createDb();
    DatabaseService.setTestDatabase(db);
    try {
      final word = await insertWord(db, difficulty: 3);
      await insertCard(db, word.id);

      final repo = ReviewRepository();
      await repo.processReviewResult(wordId: word.id, isCorrect: true);
      await repo.processReviewResult(wordId: word.id, isCorrect: true);

      expect(await fetchDifficulty(db, word.id), 1);
    } finally {
      DatabaseService.clearTestDatabase();
      await db.close();
    }
  });

  test('난이도는 1~5 범위를 유지한다 (클램프)', () async {
    final db = await createDb();
    DatabaseService.setTestDatabase(db);
    try {
      final easyWord = await insertWord(db, difficulty: 1);
      await insertCard(db, easyWord.id);
      final hardWord = await insertWord(db, difficulty: 5);
      await insertCard(db, hardWord.id);

      final repo = ReviewRepository();
      await repo.processReviewResult(wordId: easyWord.id, isCorrect: true);
      await repo.processReviewResult(wordId: hardWord.id, isCorrect: false);

      expect(await fetchDifficulty(db, easyWord.id), 1); // 최소 유지
      expect(await fetchDifficulty(db, hardWord.id), 5); // 최대 유지
    } finally {
      DatabaseService.clearTestDatabase();
      await db.close();
    }
  });

  test('리뷰카드가 없어도 난이도는 반영된다', () async {
    final db = await createDb();
    DatabaseService.setTestDatabase(db);
    try {
      final word = await insertWord(db, difficulty: 3);
      // insertCard 생략 — 리뷰카드 없음

      final repo = ReviewRepository();
      await repo.processReviewResult(wordId: word.id, isCorrect: true);

      expect(await fetchDifficulty(db, word.id), 2);
    } finally {
      DatabaseService.clearTestDatabase();
      await db.close();
    }
  });

  test('getMasteredCount: 난이도 ≤ 2 단어 수를 반환한다', () async {
    final db = await createDb();
    DatabaseService.setTestDatabase(db);
    try {
      await insertWord(db, difficulty: 1);
      await insertWord(db, difficulty: 2);
      await insertWord(db, difficulty: 3);
      await insertWord(db, difficulty: 5);

      final repo = ReviewRepository();
      expect(await repo.getMasteredCount(), 2);
    } finally {
      DatabaseService.clearTestDatabase();
      await db.close();
    }
  });

  test('auto_difficulty 꺼짐(false)이면 난이도가 반영되지 않는다', () async {
    final db = await createDb();
    DatabaseService.setTestDatabase(db);
    try {
      final word = await insertWord(db, difficulty: 3);
      await insertCard(db, word.id);
      await setSetting(db, ReviewRepository.autoDifficultySettingKey, 'false');

      final repo = ReviewRepository();
      await repo.processReviewResult(wordId: word.id, isCorrect: true);
      await repo.processReviewResult(wordId: word.id, isCorrect: false);

      expect(await fetchDifficulty(db, word.id), 3); // 그대로 유지
    } finally {
      DatabaseService.clearTestDatabase();
      await db.close();
    }
  });

  test('auto_difficulty 켜짐(true)이면 난이도가 반영된다', () async {
    final db = await createDb();
    DatabaseService.setTestDatabase(db);
    try {
      final word = await insertWord(db, difficulty: 3);
      await insertCard(db, word.id);
      await setSetting(db, ReviewRepository.autoDifficultySettingKey, 'true');

      final repo = ReviewRepository();
      await repo.processReviewResult(wordId: word.id, isCorrect: true);

      expect(await fetchDifficulty(db, word.id), 2);
    } finally {
      DatabaseService.clearTestDatabase();
      await db.close();
    }
  });

  test('MASTERED 경계: 난이도 2에서 오답 시 3으로 이탈한다', () async {
    final db = await createDb();
    DatabaseService.setTestDatabase(db);
    try {
      final word = await insertWord(db, difficulty: 2);
      await insertCard(db, word.id);

      final repo = ReviewRepository();
      await repo.processReviewResult(wordId: word.id, isCorrect: false);

      expect(await fetchDifficulty(db, word.id), 3);
    } finally {
      DatabaseService.clearTestDatabase();
      await db.close();
    }
  });
}
