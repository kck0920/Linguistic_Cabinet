import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import 'google_session_storage_stub.dart';

class GoogleSessionStorageImpl {
  static const String _webStorageKey = 'voca_google_session_v1';

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
}
