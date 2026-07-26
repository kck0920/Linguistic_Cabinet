import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

class DatabaseService {
  static Database? _database;
  static const String _dbName = 'vocatree.db';
  static const int _dbVersion = 6;

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

  static Future<Database> _initDatabase() async {
    if (kIsWeb) {
      final dbFactory = databaseFactoryFfiWeb;
      return await dbFactory.openDatabase(
          _dbName,
          options: OpenDatabaseOptions(
            version: _dbVersion,
            onCreate: _createDatabase,
            onUpgrade: (db, oldVersion, newVersion) async {
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
            },
          ),
        );
    }
    final String path = join(await getDatabasesPath(), _dbName);
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _createDatabase,
      onUpgrade: (db, oldVersion, newVersion) async {
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
      },
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
