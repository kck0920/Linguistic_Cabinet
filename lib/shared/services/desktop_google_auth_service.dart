import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'google_session_storage.dart';
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

  /// 전용 세션 저장소에서 계정 정보 불러오기 (앱 실행/Silent Sign-In 시 호출)
  Future<DesktopGoogleAccount?> loadSavedAccount() async {
    if (_currentAccount != null) {
      if (_currentAccount!.isExpired && _currentAccount!.refreshToken != null) {
        debugPrint('[DESKTOP_AUTH] Token expired, refreshing access token...');
        await refreshAccessToken();
      }
      return _currentAccount;
    }

    try {
      debugPrint('[DESKTOP_AUTH] Loading session from GoogleSessionStorage...');
      final sessionData = await GoogleSessionStorage.loadSession();
      if (sessionData != null) {
        debugPrint('[DESKTOP_AUTH] Found saved session for: ${sessionData.email}');
        var acc = DesktopGoogleAccount(
          id: sessionData.id,
          email: sessionData.email,
          displayName: sessionData.displayName,
          photoUrl: sessionData.photoUrl,
          accessToken: sessionData.accessToken,
          refreshToken: sessionData.refreshToken,
          expiresAt: sessionData.expiresAt,
        );

        _currentAccount = acc;

        if (acc.isExpired && acc.refreshToken != null) {
          debugPrint('[DESKTOP_AUTH] Saved session expired, refreshing access token...');
          await refreshAccessToken();
        }

        return _currentAccount;
      } else {
        debugPrint('[DESKTOP_AUTH] No saved session found.');
      }
    } catch (e) {
      debugPrint('DesktopGoogleAuthService loadSavedAccount Error: $e');
    }
    return null;
  }

  /// 세션 저장소에 계정 정보 영구 저장
  Future<void> _saveAccount(DesktopGoogleAccount acc) async {
    try {
      await GoogleSessionStorage.saveSession(GoogleSessionData(
        id: acc.id,
        email: acc.email,
        displayName: acc.displayName,
        photoUrl: acc.photoUrl,
        accessToken: acc.accessToken,
        refreshToken: acc.refreshToken,
        expiresAt: acc.expiresAt,
      ));
    } catch (e) {
      debugPrint('DesktopGoogleAuthService _saveAccount Error: $e');
    }
  }

  /// 세션 저장소에서 계정 정보 삭제 (로그아웃 시)
  Future<void> _clearAccount() async {
    try {
      await GoogleSessionStorage.clearSession();
    } catch (e) {
      debugPrint('DesktopGoogleAuthService _clearAccount Error: $e');
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

        await _saveAccount(_currentAccount!);
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
    if (!OAuthCredentials.hasClientSecret) {
      throw Exception(
        'OAUTH_CLIENT_SECRET이 설정되지 않았습니다. '
        '--dart-define=OAUTH_CLIENT_SECRET=... 로 빌드 시 주입해 주세요.',
      );
    }
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

      // 세션을 전용 저장소에 저장
      await _saveAccount(_currentAccount!);

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
    await _clearAccount();
  }
}
