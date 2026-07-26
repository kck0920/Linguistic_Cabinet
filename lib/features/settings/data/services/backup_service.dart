import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/utils/file_picker_helper.dart';
import '../../../../core/utils/file_saver.dart';
import '../../../words/data/models/word.dart';
import '../../../words/data/repositories/word_repository.dart';
import '../../../words/presentation/screens/word_list_screen.dart';
import '../../../review/data/models/review_card.dart';
import '../../../review/data/repositories/review_repository.dart';
import '../../../review/presentation/screens/review_screen.dart';

class BackupResult {
  final int importedCount;
  final int updatedCount;

  BackupResult({required this.importedCount, required this.updatedCount});
}

class BackupService {
  final WordRepository _wordRepository;
  final ReviewRepository _reviewRepository;

  BackupService(this._wordRepository, this._reviewRepository);

  /// 자동 백업: 앱 문서 디렉토리에 ZIP 저장
  Future<String?> autoBackup() async {
    if (kIsWeb) return null; // Web에서는 파일 시스템 접근 불가

    final words = await _wordRepository.getAllWords();
    if (words.isEmpty) return null;

    final archive = Archive();

    final jsonList = <Map<String, dynamic>>[];
    for (final word in words) {
      final wordMap = word.toMap();
      final imagePath = word.imagePath;

      if (imagePath != null && imagePath.isNotEmpty) {
        try {
          final file = File(imagePath);
          if (file.existsSync()) {
            final imageBytes = await file.readAsBytes();
            final filename = '${word.id}.jpg';
            archive.addFile(ArchiveFile('images/$filename', imageBytes.length, imageBytes));
            wordMap['image_path'] = 'images/$filename';
          }
        } catch (_) {
          wordMap['image_path'] = null;
        }
      } else {
        wordMap['image_path'] = null;
      }

      jsonList.add(wordMap);
    }

    final jsonString = const JsonEncoder.withIndent('  ').convert(jsonList);
    final jsonBytes = utf8.encode(jsonString);
    archive.addFile(ArchiveFile('words.json', jsonBytes.length, jsonBytes));

    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) return null;

    final appDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${appDir.path}/backups');
    if (!backupDir.existsSync()) {
      await backupDir.create(recursive: true);
    }

    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
    final backupPath = '${backupDir.path}/vocatree_$timestamp.zip';
    final backupFile = File(backupPath);
    await backupFile.writeAsBytes(Uint8List.fromList(zipBytes));

    // 이전 자동 백업 정리 (최근 5개 유지)
    await _cleanupOldBackups(backupDir);

    return backupPath;
  }

  Future<void> _cleanupOldBackups(Directory backupDir) async {
    final files = backupDir.listSync()
        .whereType<File>()
        .where((f) => f.path.contains('vocatree_') && f.path.endsWith('.zip'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));

    // 최근 5개만 유지
    for (final file in files.skip(5)) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  /// 자동 백업이 활성화되어 있는지 확인
  Future<bool> isAutoBackupEnabled() async {
    final value = await _reviewRepository.getSetting('auto_backup_enabled');
    return value == 'true';
  }

  /// 자동 백업 활성화/비활성화 설정
  Future<void> setAutoBackupEnabled(bool enabled) async {
    await _reviewRepository.setSetting('auto_backup_enabled', enabled ? 'true' : 'false');
  }

  Future<int> exportBackup() async {
    final words = await _wordRepository.getAllWords();
    if (words.isEmpty) {
      return 0;
    }

    final archive = Archive();

    // Collect image files and build JSON data with relative paths
    final jsonList = <Map<String, dynamic>>[];
    for (final word in words) {
      final wordMap = word.toMap();
      final imagePath = word.imagePath;

      if (imagePath != null && imagePath.isNotEmpty) {
        Uint8List? imageBytes;

        if (kIsWeb) {
          // Web: image_path is base64-encoded
          try {
            imageBytes = base64Decode(imagePath);
          } catch (_) {}
        } else {
          // Mobile/Desktop: image_path is a file path
          try {
            final file = File(imagePath);
            if (file.existsSync()) {
              imageBytes = await file.readAsBytes();
            }
          } catch (_) {}
        }

        if (imageBytes != null) {
          final filename = '${word.id}.jpg';
          archive.addFile(ArchiveFile('images/$filename', imageBytes.length, imageBytes));
          wordMap['image_path'] = 'images/$filename';
        } else {
          wordMap['image_path'] = null;
        }
      } else {
        wordMap['image_path'] = null;
      }

      jsonList.add(wordMap);
    }

    // Add JSON to archive
    final jsonString = const JsonEncoder.withIndent('  ').convert(jsonList);
    final jsonBytes = utf8.encode(jsonString);
    archive.addFile(ArchiveFile('words.json', jsonBytes.length, jsonBytes));

    // Encode as ZIP
    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) {
      throw Exception('ZIP 인코딩 실패');
    }

    await saveZipFile(Uint8List.fromList(zipBytes), 'vocatree_backup.zip');
    return words.length;
  }

  Future<BackupResult?> importBackup() async {
    final zipBytes = await pickZipFile();
    if (zipBytes == null) {
      return null; // User cancelled
    }

    return importBackupFromBytes(zipBytes);
  }

  Future<BackupResult> importBackupFromString(String jsonString) async {
    final archive = Archive();
    final jsonBytes = utf8.encode(jsonString);
    archive.addFile(ArchiveFile('words.json', jsonBytes.length, jsonBytes));
    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) {
      throw Exception('ZIP 인코딩 실패');
    }
    return importBackupFromBytes(Uint8List.fromList(zipBytes));
  }

  Future<BackupResult> importBackupFromBytes(Uint8List zipBytes) async {
    // Decode ZIP
    final archive = ZipDecoder().decodeBytes(zipBytes);

    // Find words.json
    final wordsFile = archive.findFile('words.json');
    if (wordsFile == null) {
      throw const FormatException('words.json 파일이 없습니다');
    }
    final jsonString = utf8.decode(wordsFile.content as List<int>);
    final dynamic decoded = jsonDecode(jsonString);
    if (decoded is! List) {
      throw const FormatException('올바른 백업 파일 형식이 아닙니다 (리스트 구조 필요)');
    }

    // Check if ZIP contains images
    final hasImages = archive.files.any((f) => f.name.startsWith('images/'));

    // Prepare images directory (mobile/desktop only, and only if images exist)
    String? imagesDirPath;
    if (!kIsWeb && hasImages) {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/images');
      if (!imagesDir.existsSync()) {
        await imagesDir.create(recursive: true);
      }
      imagesDirPath = imagesDir.path;
    }

    final existingWords = await _wordRepository.getAllWords();
    final existingByEnglish = {
      for (var w in existingWords) w.english.trim().toLowerCase(): w
    };

    int importedCount = 0;
    int updatedCount = 0;

    final List<Word> wordsToInsert = [];
    final List<Word> wordsToUpdate = [];

    for (final item in decoded) {
      if (item is Map<String, dynamic>) {
        final english = item['english'] as String?;
        final korean = item['korean'] as String?;

        if (english == null || english.isEmpty || korean == null || korean.isEmpty) {
          continue;
        }

        final key = english.trim().toLowerCase();
        final existing = existingByEnglish[key];

        // Resolve image_path from ZIP
        String? resolvedImagePath;
        final zipImagePath = item['image_path'] as String?;

        if (zipImagePath != null && zipImagePath.isNotEmpty) {
          final imageFile = archive.findFile(zipImagePath);

          if (imageFile != null && imageFile.content is List<int>) {
            final imageBytes = Uint8List.fromList(imageFile.content as List<int>);

            if (kIsWeb) {
              // Web: store as base64
              resolvedImagePath = base64Encode(imageBytes);
            } else {
              // Mobile/Desktop: write to images directory
              final filename = '${const Uuid().v4()}.jpg';
              final destPath = '$imagesDirPath/$filename';
              final destFile = File(destPath);
              await destFile.writeAsBytes(imageBytes);
              resolvedImagePath = destPath;
            }
          }
        }

        final word = Word(
          id: existing?.id ?? item['id'] as String?,
          english: english,
          korean: korean,
          exampleSentence: item['example_sentence'] as String?,
          pronunciation: item['pronunciation'] as String?,
          tags: item['tags'] != null
              ? (item['tags'] as String).split(',').where((t) => t.isNotEmpty).toList()
              : null,
          difficulty: item['difficulty'] as int? ?? 3,
          memo: item['memo'] as String?,
          imagePath: resolvedImagePath,
          createdAt: item['created_at'] != null ? DateTime.parse(item['created_at'] as String) : null,
          updatedAt: DateTime.now(),
        );

        if (existing != null) {
          wordsToUpdate.add(word);
          updatedCount++;
        } else {
          wordsToInsert.add(word);
          importedCount++;
        }
      }
    }

    // Perform DB batch operations
    if (wordsToInsert.isNotEmpty) {
      await _wordRepository.insertWords(wordsToInsert);
      final reviewMethodValue = await _reviewRepository.getSetting('review_method');
      final reviewMethod = reviewMethodValue == 'fixed' ? ReviewMethod.fixed : ReviewMethod.linear;
      final fixedInterval = reviewMethodValue == 'fixed'
          ? (int.tryParse(await _reviewRepository.getSetting('fixed_interval_days') ?? '') ?? 7)
          : null;
      for (final w in wordsToInsert) {
        final card = ReviewCard(
          wordId: w.id,
          reviewMethod: reviewMethod,
          fixedIntervalDays: reviewMethod == ReviewMethod.fixed ? fixedInterval : null,
          nextReviewDate: DateTime.now(),
        );
        await _reviewRepository.insertReviewCard(card);
      }
    }
    for (final w in wordsToUpdate) {
      await _wordRepository.updateWord(w);
    }

    return BackupResult(importedCount: importedCount, updatedCount: updatedCount);
  }
}

final backupServiceProvider = Provider<BackupService>((ref) {
  final wordRepository = ref.watch(wordRepositoryProvider);
  final reviewRepository = ref.watch(reviewRepositoryProvider);
  return BackupService(wordRepository, reviewRepository);
});
