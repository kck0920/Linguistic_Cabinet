import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

class DatabaseService {
  static Database? _database;
  static const String _dbName = 'vocatree.db';
  static const int _dbVersion = 7;

  // For testing - allows overriding the database instance
  static Database? _testDatabase;

  static Database? get testDatabase => _testDatabase;

  static Future<Database> get database async {
    if (_testDatabase != null) return _testDatabase!;
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // For testing - set a test database instance
  static void setTestDatabase(Database db) {
    _testDatabase = db;
  }

  // For testing - clear test database
  static void clearTestDatabase() {
    _testDatabase = null;
  }

  /// 통합 테스트용: 실제 파일 DB(vocatree.db)를 건드리지 않고
  /// 인메모리 DB로 스키마를 초기화해 테스트 DB로 지정한다.
  /// (Linux 데스크톱 등 dart:io 환경에서 사용 — 통합 테스트 전용)
  /// 호출 전에 `databaseFactory`가 sqflite_common_ffi의 ffi 팩토리로
  /// 설정되어 있어야 한다 (main.dart와 동일한 초기화).
  static Future<void> setTestDatabaseInMemory() async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: _dbVersion,
        onCreate: _createDatabase,
      ),
    );
    _testDatabase = db;
  }

  static Future<void> _addColumnSafe(Database db, String table, String column, String type, {String? defaultValue}) async {
    try {
      final defaultClause = defaultValue != null ? ' DEFAULT $defaultValue' : '';
      await db.execute('ALTER TABLE $table ADD COLUMN $column $type$defaultClause;');
    } catch (e) {
      if (!e.toString().contains('duplicate column name')) {
        rethrow;
      }
    }
  }

  /// 스키마 마이그레이션 (웹/네이티브 공통 — 버전 추가 시 여기만 수정)
  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await _addColumnSafe(db, 'words', 'image_path', 'TEXT');
    }
    if (oldVersion < 4) {
      await _addColumnSafe(db, 'review_cards', 'easiness_factor', 'REAL', defaultValue: '2.5');
      await _addColumnSafe(db, 'review_cards', 'interval', 'INTEGER', defaultValue: '0');
      await _addColumnSafe(db, 'review_cards', 'repetition', 'INTEGER', defaultValue: '0');
    }
    if (oldVersion < 5) {
      await _addColumnSafe(db, 'review_logs', 'study_method', 'TEXT');
      await _addColumnSafe(db, 'review_logs', 'duration_ms', 'INTEGER');
      await _addColumnSafe(db, 'review_logs', 'answer_type', 'TEXT');
    }
    if (oldVersion < 6) {
      await _addColumnSafe(db, 'review_cards', 'override_method', 'TEXT');
    }
    if (oldVersion < 7) {
      await _addColumnSafe(db, 'words', 'dictionary_url', 'TEXT');
    }
  }

  static Future<Database> _initDatabase() async {
    if (kIsWeb) {
      final dbFactory = databaseFactoryFfiWeb;
      return await dbFactory.openDatabase(
          _dbName,
          options: OpenDatabaseOptions(
            version: _dbVersion,
            onCreate: _createDatabase,
            onUpgrade: _onUpgrade,
          ),
        );
    }
    final String path = join(await getDatabasesPath(), _dbName);
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _createDatabase,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _createDatabase(Database db, int version) async {
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
        repetition INTEGER DEFAULT 0,
        FOREIGN KEY (word_id) REFERENCES words (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE review_logs (
        id TEXT PRIMARY KEY,
        word_id TEXT NOT NULL,
        reviewed_at TEXT NOT NULL,
        is_correct INTEGER NOT NULL,
        study_method TEXT,
        duration_ms INTEGER,
        answer_type TEXT,
        FOREIGN KEY (word_id) REFERENCES words (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Create indexes
    await db.execute('CREATE INDEX idx_words_english ON words (english)');
    await db.execute('CREATE INDEX idx_words_korean ON words (korean)');
    await db.execute('CREATE INDEX idx_review_cards_word_id ON review_cards (word_id)');
    await db.execute('CREATE INDEX idx_review_cards_next_review ON review_cards (next_review_date)');
    await db.execute('CREATE INDEX idx_review_logs_word_id ON review_logs (word_id)');
  }

  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  /// 데이터베이스 파일 바이너리(Bytes) 읽어오기 (웹/데스크톱 공통)
  static Future<List<int>?> exportDatabaseBytes() async {
    try {
      if (kIsWeb) {
        final dbFactory = databaseFactoryFfiWeb;
        final bytes = await dbFactory.readDatabaseBytes(_dbName);
        return bytes;
      } else {
        final String path = join(await getDatabasesPath(), _dbName);
        final file = File(path);
        if (await file.exists()) {
          return await file.readAsBytes();
        }
      }
      return null;
    } catch (e) {
      debugPrint('exportDatabaseBytes Error: $e');
      return null;
    }
  }

  /// 바이트 데이터로 로컬 데이터베이스 파일 교체하기 (로그인 세션 정보 보존)
  static Future<bool> importDatabaseBytes(List<int> bytes) async {
    try {
      // 1. 덮어쓰기 전 현재 기기의 구글 로그인 세션 설정 백업
      final Map<String, String> authSettingsBackup = {};
      if (_database != null && _database!.isOpen) {
        try {
          final rows = await _database!.query('settings');
          for (final r in rows) {
            final k = r['key'] as String;
            if (k.startsWith('google_auth_')) {
              authSettingsBackup[k] = r['value'] as String;
            }
          }
        } catch (e) {
          debugPrint('Failed to backup auth settings before DB import: $e');
        }
      }

      await close();
      if (kIsWeb) {
        final dbFactory = databaseFactoryFfiWeb;
        await dbFactory.writeDatabaseBytes(_dbName, Uint8List.fromList(bytes));
      } else {
        final String path = join(await getDatabasesPath(), _dbName);
        final file = File(path);
        await file.writeAsBytes(bytes, flush: true);
      }
      // 새 DB 다시 오픈
      _database = await _initDatabase();

      // 2. 덮어씌워진 DB의 settings 테이블에 로그인 세션 다시 복원
      if (authSettingsBackup.isNotEmpty) {
        try {
          final batch = _database!.batch();
          authSettingsBackup.forEach((key, value) {
            batch.insert(
              'settings',
              {'key': key, 'value': value},
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          });
          await batch.commit(noResult: true);
        } catch (e) {
          debugPrint('Failed to restore auth settings after DB import: $e');
        }
      }

      return true;
    } catch (e) {
      debugPrint('importDatabaseBytes Error: $e');
      return false;
    }
  }

  static Future<void> deleteDatabase() async {
    if (kIsWeb) {
      final dbFactory = databaseFactoryFfiWeb;
      await dbFactory.deleteDatabase(_dbName);
    } else {
      final String path = join(await getDatabasesPath(), _dbName);
      await databaseFactory.deleteDatabase(path);
    }
    _database = null;
  }
}
