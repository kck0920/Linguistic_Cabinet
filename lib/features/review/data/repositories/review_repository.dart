import 'package:sqflite/sqflite.dart';
import '../models/review_card.dart';
import '../models/study_log.dart';
import '../../../../shared/services/database_service.dart';
import '../../../words/data/repositories/word_repository.dart';

class ReviewRepository {
  /// 복습 결과 → 단어 난이도 자동 반영 설정 키 (값 'false'면 비활성, 기본 활성).
  static const String autoDifficultySettingKey = 'auto_difficulty';

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

  /// 여러 설정을 한 번에 조회한다 (업적 수여 루프 등에서 개별 쿼리를
  /// N번 날리는 대신 `WHERE key IN (...)` 한 번으로 처리해 성능을 개선).
  Future<Map<String, String>> getSettings(List<String> keys) async {
    if (keys.isEmpty) return {};
    final db = await DatabaseService.database;
    final placeholders = List.filled(keys.length, '?').join(', ');
    final List<Map<String, dynamic>> maps = await db.query(
      'settings',
      where: 'key IN ($placeholders)',
      whereArgs: keys,
    );
    return {
      for (final row in maps) row['key'] as String: row['value'] as String,
    };
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

  /// 복습 결과에 따라 설정된 activeMethod 기반으로 리뷰카드 업데이트
  /// 하고, 복습 결과(정답/오답)를 단어 난이도에 자동 반영한다.
  Future<void> processReviewResult({
    required String wordId,
    required bool isCorrect,
    int quality = 4,
  }) async {
    final card = await getReviewCardByWordId(wordId);
    if (card != null) {
      final updatedCard = card.processReviewResult(isCorrect: isCorrect, quality: quality);
      await updateReviewCard(updatedCard);
    }

    // 복습 결과를 단어 난이도에 자동 반영 (정답 -1, 오답 +1, 1~5 범위).
    // 설정 'auto_difficulty'가 'false'면 비활성화 (기본: 설정 없음 = 활성화).
    // 난이도 갱신은 2차 부수 효과이므로, 실패해도 복습 기록 경로를 막지 않도록
    // 격리한다. 카드 존재 여부와도 독립적으로 처리한다.
    try {
      final setting = await getSetting(ReviewRepository.autoDifficultySettingKey);
      final enabled = setting == null || setting != 'false';
      if (enabled) {
        await _applyReviewToDifficulty(wordId: wordId, isCorrect: isCorrect);
      }
    } catch (_) {
      // 복습 카드 갱신은 이미 완료 — 난이도 반영 실패는 무시한다.
    }
  }

  /// 복습 결과(정답/오답)를 해당 단어의 난이도에 반영한다.
  /// 정답이면 난이도를 1 낮추고(숙달), 오답이면 1 올린다(어려움). 1~5 범위 유지.
  Future<void> _applyReviewToDifficulty({
    required String wordId,
    required bool isCorrect,
  }) async {
    final wordRepo = WordRepository();
    final word = await wordRepo.getWordById(wordId);
    if (word == null) return;
    final adjusted = word.adjustedDifficultyForReview(isCorrect: isCorrect);
    if (adjusted == word.difficulty) return;
    await wordRepo.updateWord(word.copyWith(difficulty: adjusted));
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

  /// 숙달(Mastered) 단어 수: 난이도 ≤ 2인 단어 개수.
  /// 복습 결과 난이도 자동 반영(auto_difficulty)과 연동되어,
  /// 마스터드 업적(Mastered 50/200/500)·LEDGER SUMMARY 집계에 사용된다.
  Future<int> getMasteredCount() async {
    final db = await DatabaseService.database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as count FROM words WHERE difficulty <= 2');
    return result.first['count'] as int;
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

  /// 각 달(1~12)의 '최대 학습 일수' (연도 무관, 모든 연도 중 최대치).
  /// 예: 2025년 3월에 15일, 2026년 3월에 23일 학습 → {3: 23}.
  /// 월간 업적(각 달 20일 이상 학습) 평가에 사용된다.
  Future<Map<int, int>> getMonthlyStudyDayCounts() async {
    final db = await DatabaseService.database;
    final result = await db.rawQuery(
      'SELECT DISTINCT DATE(reviewed_at) as date FROM review_logs',
    );

    // (연도-월) → 서로 다른 날짜 집합
    final Map<String, Set<String>> byYearMonth = {};
    for (final row in result) {
      final dateStr = row['date'] as String?;
      if (dateStr == null || dateStr.length < 8) continue;
      final yearMonth = dateStr.substring(0, 7); // yyyy-mm
      byYearMonth.putIfAbsent(yearMonth, () => <String>{}).add(dateStr);
    }

    // 달(1~12) → 모든 연도 중 가장 많은 학습 일수
    final Map<int, int> maxByMonth = {};
    byYearMonth.forEach((yearMonth, dates) {
      final month = int.tryParse(yearMonth.substring(5, 7));
      if (month == null) return;
      final count = dates.length;
      if (count > (maxByMonth[month] ?? 0)) {
        maxByMonth[month] = count;
      }
    });
    return maxByMonth;
  }

  /// 현재 연속 학습 일수 (Current Streak Days) 계산
  Future<int> getCurrentStreakDays() async {
    final db = await DatabaseService.database;
    final result = await db.rawQuery(
      "SELECT DISTINCT DATE(reviewed_at) as date FROM review_logs ORDER BY date DESC",
    );

    if (result.isEmpty) return 0;

    final Set<String> activeDates = result
        .map((r) => r['date'] as String?)
        .whereType<String>()
        .toSet();

    final now = DateTime.now();
    DateTime checkDate = DateTime(now.year, now.month, now.day);
    String todayKey =
        "${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}";

    DateTime yesterday = checkDate.subtract(const Duration(days: 1));
    String yesterdayKey =
        "${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";

    if (!activeDates.contains(todayKey) && !activeDates.contains(yesterdayKey)) {
      return 0;
    }

    int streak = 0;
    if (!activeDates.contains(todayKey)) {
      checkDate = yesterday;
    }

    while (true) {
      String key =
          "${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}";
      if (activeDates.contains(key)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return streak;
  }
}
