import 'package:sqflite/sqflite.dart';
import '../models/review_card.dart';
import '../models/study_log.dart';
import '../../../../shared/services/database_service.dart';
import '../../../words/data/repositories/word_repository.dart';

class ReviewRepository {
  Future<String?> getSetting(String key) async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isEmpty) return null;
    return maps.first['value'] as String;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await DatabaseService.database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  Future<List<ReviewCard>> getAllReviewCards() async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.query('review_cards');
    return maps.map((map) => ReviewCard.fromMap(map)).toList();
  }

  Future<ReviewCard?> getReviewCardByWordId(String wordId) async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'review_cards',
      where: 'word_id = ?',
      whereArgs: [wordId],
    );
    if (maps.isEmpty) return null;
    return ReviewCard.fromMap(maps.first);
  }

  Future<List<ReviewCard>> getDueReviewCards() async {
    final db = await DatabaseService.database;
    final now = DateTime.now().toIso8601String();
    final List<Map<String, dynamic>> maps = await db.query(
      'review_cards',
      where: 'next_review_date <= ?',
      whereArgs: [now],
    );
    return maps.map((map) => ReviewCard.fromMap(map)).toList();
  }

  Future<void> insertReviewCard(ReviewCard card) async {
    final db = await DatabaseService.database;
    await db.insert('review_cards', card.toMap());
  }

  Future<void> updateReviewCard(ReviewCard card) async {
    final db = await DatabaseService.database;
    await db.update(
      'review_cards',
      card.toMap(),
      where: 'id = ?',
      whereArgs: [card.id],
    );
  }

  Future<void> deleteReviewCard(String id) async {
    final db = await DatabaseService.database;
    await db.delete(
      'review_cards',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteReviewCardByWordId(String wordId) async {
    final db = await DatabaseService.database;
    await db.delete(
      'review_cards',
      where: 'word_id = ?',
      whereArgs: [wordId],
    );
  }

  Future<void> deleteAllReviewCards() async {
    final db = await DatabaseService.database;
    await db.delete('review_cards');
  }

  Future<void> logReview({
    required String wordId,
    required bool isCorrect,
    String? studyMethod,
    int? durationMs,
    String? answerType,
  }) async {
    final log = StudyLog.create(
      wordId: wordId,
      isCorrect: isCorrect,
      studyMethod: studyMethod,
      durationMs: durationMs,
      answerType: answerType,
    );
    final db = await DatabaseService.database;
    await db.insert('review_logs', log.toMap());
  }

  /// 오늘 복습한 기록이 있는지 확인
  Future<bool> hasReviewedToday() async {
    final db = await DatabaseService.database;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM review_logs WHERE reviewed_at >= ? AND reviewed_at < ?',
      [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
    );
    
    final count = result.first['count'] as int;
    return count > 0;
  }

  /// 특정 단어의 학습 이력 조회
  Future<List<StudyLog>> getStudyLogsByWordId(String wordId) async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'review_logs',
      where: 'word_id = ?',
      whereArgs: [wordId],
      orderBy: 'reviewed_at DESC',
    );
    return maps.map((map) => StudyLog.fromMap(map)).toList();
  }

  /// 전체 학습 이력 조회
  Future<List<StudyLog>> getAllStudyLogs({int? limit}) async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'review_logs',
      orderBy: 'reviewed_at DESC',
      limit: limit,
    );
    return maps.map((map) => StudyLog.fromMap(map)).toList();
  }

  /// SM-2 알고리즘에 따라 리뷰카드 업데이트
  /// quality: 0-5 (0=가장 나쁨, 5=가장 좋음)
  Future<void> updateReviewCardWithSM2({
    required String wordId,
    required int quality,
  }) async {
    final card = await getReviewCardByWordId(wordId);
    if (card == null) return;
    
    final updatedCard = card.updateWithSM2(quality);
    await updateReviewCard(updatedCard);
  }

  /// 리뷰카드가 없는 단어들을 찾아서 자동으로 생성
  Future<int> ensureReviewCardsExist() async {
    final wordRepo = WordRepository();
    final allWords = await wordRepo.getAllWords();
    final existingCards = await getAllReviewCards();
    
    // 리뷰카드가 없는 단어 ID 목록
    final existingWordIds = existingCards.map((card) => card.wordId).toSet();
    final wordsNeedingCards = allWords.where((word) => !existingWordIds.contains(word.id)).toList();
    
    if (wordsNeedingCards.isEmpty) return 0;
    
    // 현재 설정된 복습 방식 가져오기
    final methodValue = await getSetting('review_method');
    ReviewMethod method;
    switch (methodValue) {
      case 'fixed':
        method = ReviewMethod.fixed;
        break;
      case 'sm2':
        method = ReviewMethod.sm2;
        break;
      default:
        method = ReviewMethod.linear;
    }
    
    // 고정 간격 설정
    int? fixedDays;
    if (method == ReviewMethod.fixed) {
      final fixedValue = await getSetting('fixed_interval_days');
      fixedDays = fixedValue != null ? int.tryParse(fixedValue) : 7;
    }
    
    // 리뷰카드 생성 (오늘 바로 복습 가능하도록)
    for (final word in wordsNeedingCards) {
      final card = ReviewCard(
        wordId: word.id,
        reviewMethod: method,
        fixedIntervalDays: fixedDays,
        nextReviewDate: DateTime.now(), // 오늘 바로 복습 가능
        reviewCount: 0,
      );
      await insertReviewCard(card);
    }
    
    return wordsNeedingCards.length;
  }

  Future<Map<String, dynamic>> getReviewStats() async {
    final db = await DatabaseService.database;
    
    final totalWords = await db.rawQuery('SELECT COUNT(*) as count FROM words');
    final dueCards = await db.rawQuery(
      'SELECT COUNT(*) as count FROM review_cards WHERE next_review_date <= ?',
      [DateTime.now().toIso8601String()],
    );
    final totalReviews = await db.rawQuery('SELECT COUNT(*) as count FROM review_logs');
    final correctReviews = await db.rawQuery(
      'SELECT COUNT(*) as count FROM review_logs WHERE is_correct = 1',
    );

    final totalCount = totalWords.first['count'] as int;
    final dueCount = dueCards.first['count'] as int;
    final reviewCount = totalReviews.first['count'] as int;
    final correctCount = correctReviews.first['count'] as int;

    return {
      'totalWords': totalCount,
      'dueForReview': dueCount,
      'totalReviews': reviewCount,
      'accuracy': reviewCount > 0 ? (correctCount / reviewCount * 100).round() : 0,
    };
  }

  /// 최근 182일간의 실제 학습 스트릭 잔디 데이터 (0~4 level)
  Future<List<int>> getStreakGridData({int days = 182}) async {
    final db = await DatabaseService.database;
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));

    final result = await db.rawQuery(
      "SELECT DATE(reviewed_at) as date, COUNT(*) as count FROM review_logs WHERE reviewed_at >= ? GROUP BY DATE(reviewed_at)",
      [startDate.toIso8601String()],
    );

    final Map<String, int> dateCounts = {};
    for (final row in result) {
      final dateStr = row['date'] as String?;
      final count = row['count'] as int? ?? 0;
      if (dateStr != null) {
        dateCounts[dateStr] = count;
      }
    }

    final List<int> streakLevels = [];
    for (int i = 0; i < days; i++) {
      final curDate = startDate.add(Duration(days: i));
      final dateKey = "${curDate.year}-${curDate.month.toString().padLeft(2, '0')}-${curDate.day.toString().padLeft(2, '0')}";
      final count = dateCounts[dateKey] ?? 0;

      int lvl = 0;
      if (count >= 8) {
        lvl = 4;
      } else if (count >= 5) {
        lvl = 3;
      } else if (count >= 3) {
        lvl = 2;
      } else if (count >= 1) {
        lvl = 1;
      }
      streakLevels.add(lvl);
    }

    return streakLevels;
  }
}
