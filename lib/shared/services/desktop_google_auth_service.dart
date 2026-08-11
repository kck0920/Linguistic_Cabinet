import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:url_launcher/url_launcher.dart';
import 'database_service.dart';
import 'oauth_credentials.dart';

class DesktopGoogleAccount {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final String accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;

  DesktopGoogleAccount({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    required this.accessToken,
    this.refreshToken,
    this.expiresAt,
  });

  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!.subtract(const Duration(minutes: 5)));

  Map<String, String> get authHeaders => {
        'Authorization': 'Bearer $accessToken',
      };
}

class DesktopGoogleAuthService {
  static final DesktopGoogleAuthService _instance = DesktopGoogleAuthService._internal();
  factory DesktopGoogleAuthService() => _instance;
  DesktopGoogleAuthService._internal();

  static const String clientId = OAuthCredentials.clientId;
  static const String clientSecret = OAuthCredentials.clientSecret;
  static const List<String> scopes = [
    'email',
    'profile',
    'https://www.googleapis.com/auth/drive.appdata',
  ];

  DesktopGoogleAccount? _currentAccount;
  DesktopGoogleAccount? get currentAccount => _currentAccount;

  String _generateCodeVerifier() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64UrlEncode(values).replaceAll('=', '');
  }

  String _generateCodeChallenge(String codeVerifier) {
    final bytes = utf8.encode(codeVerifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  /// DB에 저장된 계정 세션 정보 불러오기 (앱 실행/Silent Sign-In 시 호출)
  Future<DesktopGoogleAccount?> loadSavedAccount() async {
    if (_currentAccount != null) {
      if (_currentAccount!.isExpired && _currentAccount!.refreshToken != null) {
        await refreshAccessToken();
      }
      return _currentAccount;
    }

    try {
      final db = await DatabaseService.database;
      final rows = await db.query('settings', where: 'key LIKE ?', whereArgs: ['google_auth_%']);
      final map = <String, String>{};
      for (final r in rows) {
        map[r['key'] as String] = r['value'] as String;
      }

      final id = map['google_auth_user_id'];
      final email = map['google_auth_email'];
      final accessToken = map['google_auth_access_token'];

      if (id != null && email != null && accessToken != null) {
        final refreshToken = map['google_auth_refresh_token'];
        final expiresAtMillis = int.tryParse(map['google_auth_expires_at'] ?? '');
        final expiresAt = expiresAtMillis != null
            ? DateTime.fromMillisecondsSinceEpoch(expiresAtMillis)
            : null;

        var acc = DesktopGoogleAccount(
          id: id,
          email: email,
          displayName: map['google_auth_display_name'],
          photoUrl: map['google_auth_photo_url'],
          accessToken: accessToken,
          refreshToken: refreshToken,
          expiresAt: expiresAt,
        );

        _currentAccount = acc;

        if (acc.isExpired && refreshToken != null) {
          await refreshAccessToken();
        }

        return _currentAccount;
      }
    } catch (e) {
      debugPrint('DesktopGoogleAuthService loadSavedAccount Error: $e');
    }
    return null;
  }

  /// DB에 계정 세션 정보 영구 저장
  Future<void> _saveAccountToDb(DesktopGoogleAccount acc) async {
    try {
      final db = await DatabaseService.database;
      final batch = db.batch();

      void insertSetting(String key, String? val) {
        if (val != null) {
          batch.insert(
            'settings',
            {'key': key, 'value': val},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      insertSetting('google_auth_user_id', acc.id);
      insertSetting('google_auth_email', acc.email);
      insertSetting('google_auth_display_name', acc.displayName);
      insertSetting('google_auth_photo_url', acc.photoUrl);
      insertSetting('google_auth_access_token', acc.accessToken);
      insertSetting('google_auth_refresh_token', acc.refreshToken);
      insertSetting('google_auth_expires_at', acc.expiresAt?.millisecondsSinceEpoch.toString());

      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('DesktopGoogleAuthService _saveAccountToDb Error: $e');
    }
  }

  /// DB에서 계정 세션 삭제 (로그아웃 시)
  Future<void> _clearAccountFromDb() async {
    try {
      final db = await DatabaseService.database;
      await db.delete('settings', where: 'key LIKE ?', whereArgs: ['google_auth_%']);
    } catch (e) {
      debugPrint('DesktopGoogleAuthService _clearAccountFromDb Error: $e');
    }
  }

  /// Refresh Token을 사용하여 Access Token 자동 갱신
  Future<String?> refreshAccessToken() async {
    if (_currentAccount == null || _currentAccount!.refreshToken == null) return null;

    try {
      final response = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        body: {
          'client_id': clientId,
          'client_secret': clientSecret,
          'grant_type': 'refresh_token',
          'refresh_token': _currentAccount!.refreshToken!,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newAccessToken = data['access_token'] as String;
        final expiresIn = data['expires_in'] as int? ?? 3600;
        final newExpiresAt = DateTime.now().add(Duration(seconds: expiresIn));

        _currentAccount = DesktopGoogleAccount(
          id: _currentAccount!.id,
          email: _currentAccount!.email,
          displayName: _currentAccount!.displayName,
          photoUrl: _currentAccount!.photoUrl,
          accessToken: newAccessToken,
          refreshToken: _currentAccount!.refreshToken,
          expiresAt: newExpiresAt,
        );

        await _saveAccountToDb(_currentAccount!);
        return newAccessToken;
      } else {
        debugPrint('DesktopGoogleAuthService refreshAccessToken Failed: ${response.body}');
      }
    } catch (e) {
      debugPrint('DesktopGoogleAuthService refreshAccessToken Error: $e');
    }
    return null;
  }

  Future<DesktopGoogleAccount?> signIn() async {
    HttpServer? server;
    try {
      // 1. 고정 선호 포트 시도 (8080, 8081, 8888 등)
      final preferredPorts = [8080, 8081, 8888];
      for (final p in preferredPorts) {
        try {
          server = await HttpServer.bind(InternetAddress.loopbackIPv4, p);
          break;
        } catch (_) {}
      }
      server ??= await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

      final port = server.port;
      final redirectUri = 'http://127.0.0.1:$port/';

      final codeVerifier = _generateCodeVerifier();
      final codeChallenge = _generateCodeChallenge(codeVerifier);

      final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': scopes.join(' '),
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
        'access_type': 'offline',
        'prompt': 'consent',
      });

      // 2. 시스템 기본 웹 브라우저 열기
      if (await canLaunchUrl(authUrl)) {
        await launchUrl(authUrl, mode: LaunchMode.externalApplication);
      } else {
        await Process.run('xdg-open', [authUrl.toString()]);
      }

      // 3. 브라우저 인증 완료 후 리다이렉트 수신 대기 (최대 3분)
      final request = await server.first.timeout(const Duration(minutes: 3));
      final code = request.uri.queryParameters['code'];

      // 응답 웹페이지 전송
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.html
        ..write('''
          <!DOCTYPE html>
          <html>
          <head><meta charset="utf-8"><title>VocaTree 로그인 완료</title></head>
          <body style="font-family: sans-serif; text-align: center; padding-top: 50px;">
            <h2>🎉 VocaTree (Linguistic Cabinet) 구글 로그인 완료!</h2>
            <p>이 브라우저 창을 닫고 앱으로 돌아가셔도 좋습니다.</p>
            <script>setTimeout(function() { window.close(); }, 2000);</script>
          </body>
          </html>
        ''');
      await request.response.close();

      if (code == null) {
        throw Exception('No auth code received from Google');
      }

      // 4. Auth Code를 Access Token으로 교환 (PKCE code_verifier 및 client_secret 포함)
      final tokenResponse = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        body: {
          'client_id': clientId,
          'client_secret': clientSecret,
          'code': code,
          'grant_type': 'authorization_code',
          'redirect_uri': redirectUri,
          'code_verifier': codeVerifier,
        },
      );

      if (tokenResponse.statusCode != 200) {
        throw Exception('Failed to get access token: ${tokenResponse.body}');
      }

      final tokenData = jsonDecode(tokenResponse.body);
      final accessToken = tokenData['access_token'] as String;
      final refreshToken = tokenData['refresh_token'] as String?;
      final expiresIn = tokenData['expires_in'] as int? ?? 3600;
      final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));

      // 5. Userinfo 조회
      final userInfoResponse = await http.get(
        Uri.parse('https://www.googleapis.com/oauth2/v3/userinfo'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (userInfoResponse.statusCode != 200) {
        throw Exception('Failed to get user info: ${userInfoResponse.body}');
      }

      final userInfo = jsonDecode(userInfoResponse.body);

      _currentAccount = DesktopGoogleAccount(
        id: userInfo['sub'] ?? '',
        email: userInfo['email'] ?? '',
        displayName: userInfo['name'],
        photoUrl: userInfo['picture'],
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresAt: expiresAt,
      );

      // 세션을 DB에 안전하게 보관하여 앱을 닫거나 포커스가 변경되어도 영구 유지되도록 함
      await _saveAccountToDb(_currentAccount!);

      return _currentAccount;
    } catch (e) {
      debugPrint('DesktopGoogleAuthService signIn error: $e');
      rethrow;
    } finally {
      await server?.close();
    }
  }

  Future<void> signOut() async {
    _currentAccount = null;
    await _clearAccountFromDb();
  }
}
