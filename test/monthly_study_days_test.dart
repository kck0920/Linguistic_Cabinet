import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:linguistic_cabinet/features/review/data/repositories/review_repository.dart';
import 'package:linguistic_cabinet/shared/services/database_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<Database> createDb() async {
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    // 실제 스키마 중 review_logs의 필요한 컬럼만 최소 구성
    await db.execute('''
      CREATE TABLE review_logs (
        id TEXT PRIMARY KEY,
        word_id TEXT NOT NULL,
        reviewed_at TEXT NOT NULL,
        is_correct INTEGER NOT NULL
      )
    ''');
    return db;
  }

  Future<void> seedLogs(Database db, DateTime start, int days) async {
    for (int d = 0; d < days; d++) {
      final date = start.add(Duration(days: d));
      await db.insert('review_logs', {
        'id': '${start.millisecondsSinceEpoch}_$d',
        'word_id': 'w1',
        'reviewed_at': date.toIso8601String(),
        'is_correct': 1,
      });
    }
  }

  test('월별 최대 학습 일수를 연도 무관으로 계산한다', () async {
    final db = await createDb();
    DatabaseService.setTestDatabase(db);
    try {
      final repo = ReviewRepository();

      // 2025년 3월: 15일 학습
      await seedLogs(db, DateTime(2025, 3, 1), 15);
      // 2026년 3월: 23일 학습 (→ 3월 최대치 23)
      await seedLogs(db, DateTime(2026, 3, 1), 23);
      // 2026년 1월: 10일 학습
      await seedLogs(db, DateTime(2026, 1, 1), 10);

      final counts = await repo.getMonthlyStudyDayCounts();

      expect(counts[3], 23); // 두 해의 3월 중 최대치
      expect(counts[1], 10);
      expect(counts.containsKey(2), isFalse); // 학습 기록 없는 달
      expect(counts.containsKey(4), isFalse);
    } finally {
      DatabaseService.clearTestDatabase();
      await db.close();
    }
  });

  test('학습 기록이 없으면 빈 맵을 반환한다', () async {
    final db = await createDb();
    DatabaseService.setTestDatabase(db);
    try {
      final repo = ReviewRepository();
      final counts = await repo.getMonthlyStudyDayCounts();
      expect(counts, isEmpty);
    } finally {
      DatabaseService.clearTestDatabase();
      await db.close();
    }
  });
}
