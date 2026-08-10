import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class DesktopGoogleAccount {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final String accessToken;

  DesktopGoogleAccount({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    required this.accessToken,
  });

  Map<String, String> get authHeaders => {
        'Authorization': 'Bearer $accessToken',
      };
}

class DesktopGoogleAuthService {
  static final DesktopGoogleAuthService _instance = DesktopGoogleAuthService._internal();
  factory DesktopGoogleAuthService() => _instance;
  DesktopGoogleAuthService._internal();

  static const String clientId = '1002909356316-gmvaad67pf9piq2q3n5co16124pb12ir.apps.googleusercontent.com';
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

      // 4. Auth Code를 Access Token으로 교환 (PKCE code_verifier 포함)
      final tokenResponse = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        body: {
          'client_id': clientId,
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
      );

      return _currentAccount;
    } catch (e) {
      debugPrint('DesktopGoogleAuthService signIn error: $e');
      rethrow;
    } finally {
      await server?.close();
    }
  }

  void signOut() {
    _currentAccount = null;
  }
}
