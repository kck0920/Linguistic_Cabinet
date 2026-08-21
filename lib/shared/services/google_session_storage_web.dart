import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:web/web.dart' as web;
import 'database_service.dart';
import 'google_session_storage_stub.dart';

class GoogleSessionStorageImpl {
  static const String _webStorageKey = 'voca_google_session_v1';
  static const String _pendingSyncKey = 'voca_google_pending_sync_v1';
  static const String _dbBackupKey = 'voca_google_session_backup_v1';

  static Future<void> saveSession(GoogleSessionData session) async {
    final jsonStr = jsonEncode(session.toJson());
    try {
      web.window.localStorage.setItem(_webStorageKey, jsonStr);
    } catch (e) {
      debugPrint('Error saving Google session web localStorage: $e');
    }

    // SQLite settings 테이블에 2차 영구 백업 (iOS Safari ITP localStorage 초기화 대비)
    try {
      final db = await DatabaseService.database;
      await db.insert(
        'settings',
        {'key': _dbBackupKey, 'value': jsonStr},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Error saving Google session to SQLite backup: $e');
    }
  }

  static Future<GoogleSessionData?> loadSession() async {
    String? jsonStr;
    try {
      jsonStr = web.window.localStorage.getItem(_webStorageKey);
    } catch (e) {
      debugPrint('Error loading Google session web localStorage: $e');
    }

    // 1차: localStorage
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        final session = GoogleSessionData.fromJson(map);
        // SQLite 백업 비동기 동기화
        _syncToDbBackup(jsonStr);
        return session;
      } catch (e) {
        debugPrint('Error parsing session JSON from localStorage: $e');
      }
    }

    // 2차: SQLite settings 테이블에서 복원 (Safari가 localStorage를 비운 경우)
    try {
      final db = await DatabaseService.database;
      final maps = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: [_dbBackupKey],
      );
      if (maps.isNotEmpty) {
        final val = maps.first['value'] as String?;
        if (val != null && val.isNotEmpty) {
          final map = jsonDecode(val) as Map<String, dynamic>;
          final session = GoogleSessionData.fromJson(map);
          // localStorage에도 다시 복원
          try {
            web.window.localStorage.setItem(_webStorageKey, val);
          } catch (_) {}
          debugPrint('Google session successfully restored from SQLite backup!');
          return session;
        }
      }
    } catch (e) {
      debugPrint('Error restoring Google session from SQLite backup: $e');
    }

    return null;
  }

  static void _syncToDbBackup(String jsonStr) async {
    try {
      final db = await DatabaseService.database;
      await db.insert(
        'settings',
        {'key': _dbBackupKey, 'value': jsonStr},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  static Future<void> clearSession() async {
    try {
      web.window.localStorage.removeItem(_webStorageKey);
    } catch (e) {
      debugPrint('Error clearing Google session web: $e');
    }

    try {
      final db = await DatabaseService.database;
      await db.delete(
        'settings',
        where: 'key = ?',
        whereArgs: [_dbBackupKey],
      );
    } catch (e) {
      debugPrint('Error clearing Google session from SQLite backup: $e');
    }
  }

  /// 리다이렉트 재인증으로 이동하기 전에 보류 중인 동기화 의도를 저장한다.
  /// (복귀 후 자동 동기화 재개용)
  static Future<void> setPendingSync(bool pending) async {
    try {
      if (pending) {
        web.window.localStorage.setItem(_pendingSyncKey, '1');
      } else {
        web.window.localStorage.removeItem(_pendingSyncKey);
      }
    } catch (e) {
      debugPrint('Error setting pending sync web: $e');
    }
  }

  /// 보류 중인 동기화 의도가 있는지 조회한다.
  static Future<bool> hasPendingSync() async {
    try {
      return web.window.localStorage.getItem(_pendingSyncKey) == '1';
    } catch (e) {
      debugPrint('Error reading pending sync web: $e');
      return false;
    }
  }
}
