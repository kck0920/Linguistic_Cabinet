import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import 'google_session_storage_stub.dart';

class GoogleSessionStorageImpl {
  static const String _webStorageKey = 'voca_google_session_v1';
  static const String _pendingSyncKey = 'voca_google_pending_sync_v1';

  static Future<void> saveSession(GoogleSessionData session) async {
    try {
      final jsonStr = jsonEncode(session.toJson());
      web.window.localStorage.setItem(_webStorageKey, jsonStr);
    } catch (e) {
      debugPrint('Error saving Google session web: $e');
    }
  }

  static Future<GoogleSessionData?> loadSession() async {
    try {
      final jsonStr = web.window.localStorage.getItem(_webStorageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        return GoogleSessionData.fromJson(map);
      }
    } catch (e) {
      debugPrint('Error loading Google session web: $e');
    }
    return null;
  }

  static Future<void> clearSession() async {
    try {
      web.window.localStorage.removeItem(_webStorageKey);
    } catch (e) {
      debugPrint('Error clearing Google session web: $e');
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
