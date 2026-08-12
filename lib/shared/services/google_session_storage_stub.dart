import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class GoogleSessionData {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final String accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;

  GoogleSessionData({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    required this.accessToken,
    this.refreshToken,
    this.expiresAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'expiresAt': expiresAt?.millisecondsSinceEpoch,
      };

  factory GoogleSessionData.fromJson(Map<String, dynamic> json) => GoogleSessionData(
        id: json['id'] as String,
        email: json['email'] as String,
        displayName: json['displayName'] as String?,
        photoUrl: json['photoUrl'] as String?,
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String?,
        expiresAt: json['expiresAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(json['expiresAt'] as int)
            : null,
      );
}

class GoogleSessionStorageImpl {
  static const String _sessionFileName = 'google_session.json';

  static Future<File?> _getSessionFile() async {
    try {
      final dir = await getApplicationSupportDirectory();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return File(p.join(dir.path, _sessionFileName));
    } catch (e) {
      debugPrint('Error getting session file path: $e');
      return null;
    }
  }

  static Future<void> saveSession(GoogleSessionData session) async {
    try {
      final jsonStr = jsonEncode(session.toJson());
      final file = await _getSessionFile();
      if (file != null) {
        await file.writeAsString(jsonStr, flush: true);
      }
    } catch (e) {
      debugPrint('Error saving Google session: $e');
    }
  }

  static Future<GoogleSessionData?> loadSession() async {
    try {
      final file = await _getSessionFile();
      if (file != null && await file.exists()) {
        final jsonStr = await file.readAsString();
        if (jsonStr.isNotEmpty) {
          final map = jsonDecode(jsonStr) as Map<String, dynamic>;
          return GoogleSessionData.fromJson(map);
        }
      }
    } catch (e) {
      debugPrint('Error loading Google session: $e');
    }
    return null;
  }

  static Future<void> clearSession() async {
    try {
      final file = await _getSessionFile();
      if (file != null && await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error clearing Google session: $e');
    }
  }

  /// 웹 리다이렉트 재인증 중 보류 중인 동기화 의도를 저장한다. (웹 전용 — 다른
  /// 플랫폼에서는 무동작)
  static Future<void> setPendingSync(bool pending) async {}

  /// 보류 중인 동기화 의도가 있는지 조회한다. (웹 전용 — 다른 플랫폼에서는 false)
  static Future<bool> hasPendingSync() async => false;
}
