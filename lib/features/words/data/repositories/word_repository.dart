import '../models/word.dart';
import '../../../../shared/services/database_service.dart';

class WordRepository {
  Future<List<Word>> getAllWords() async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.query('words');
    return maps.map((map) => Word.fromMap(map)).toList();
  }

  Future<Word?> getWordById(String id) async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'words',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Word.fromMap(maps.first);
  }

  Future<List<Word>> searchWords(String query) async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'words',
      where: 'english LIKE ? OR korean LIKE ? OR tags LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
    );
    return maps.map((map) => Word.fromMap(map)).toList();
  }

  Future<List<Word>> getWordsByTag(String tag) async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'words',
      where: 'tags LIKE ?',
      whereArgs: ['%$tag%'],
    );
    return maps.map((map) => Word.fromMap(map)).toList();
  }

  Future<List<Word>> getWordsByDifficulty(int difficulty) async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'words',
      where: 'difficulty = ?',
      whereArgs: [difficulty],
    );
    return maps.map((map) => Word.fromMap(map)).toList();
  }

  Future<void> insertWord(Word word) async {
    final db = await DatabaseService.database;
    await db.insert('words', word.toMap());
  }

  Future<void> insertWords(List<Word> words) async {
    final db = await DatabaseService.database;
    final batch = db.batch();
    for (final word in words) {
      batch.insert('words', word.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateWord(Word word) async {
    final db = await DatabaseService.database;
    await db.update(
      'words',
      word.toMap(),
      where: 'id = ?',
      whereArgs: [word.id],
    );
  }

  Future<void> deleteWord(String id) async {
    final db = await DatabaseService.database;
    await db.delete(
      'words',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteAllWords() async {
    final db = await DatabaseService.database;
    await db.delete('words');
  }

  Future<int> getWordCount() async {
    final db = await DatabaseService.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM words');
    return result.first['count'] as int;
  }

  Future<List<String>> getAllTags() async {
    final db = await DatabaseService.database;
    final result = await db.rawQuery('SELECT DISTINCT tags FROM words');
    final Set<String> tags = {};
    for (final row in result) {
      final tagsStr = row['tags'] as String?;
      if (tagsStr != null && tagsStr.isNotEmpty) {
        tags.addAll(tagsStr.split(',').where((t) => t.isNotEmpty));
      }
    }
    return tags.toList()..sort();
  }
}
