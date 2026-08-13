import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import 'google_token_refresh_stub.dart';

@JS('requestGoogleAuthCode')
external void _requestGoogleAuthCode(
  JSString clientId,
  JSString scopesStr,
  JSFunction callback,
);

@JS('consumeRedirectCode')
external JSString? _consumeRedirectCode();

class GoogleTokenRefresher {
  /// 모바일/리다이렉트 복귀 시 URL 쿼리스트링에서 authorization_code 회수
  static String? consumeRedirectCode() {
    try {
      final codeObj = _consumeRedirectCode();
      if (codeObj != null && codeObj.toDart.isNotEmpty) {
        return codeObj.toDart;
      }
    } catch (e) {
      debugPrint('consumeRedirectCode error: $e');
    }
    return null;
  }

  /// 웹: GIS initCodeClient 팝업/리다이렉트를 통해 authorization_code를 수신한다.
  static Future<String?> requestAuthCode({
    required String clientId,
    required List<String> scopes,
  }) async {
    try {
      final completer = Completer<String?>();
      final scopesStr = scopes.join(' ');

      final jsCallback = (JSString? code, JSString? err) {
        if (!completer.isCompleted) {
          if (err != null && err.toDart.isNotEmpty) {
            debugPrint('requestAuthCode error: ${err.toDart}');
            completer.complete(null);
          } else if (code != null && code.toDart.isNotEmpty) {
            completer.complete(code.toDart);
          } else {
            completer.complete(null);
          }
        }
      }.toJS;

      _requestGoogleAuthCode(
        clientId.toJS,
        scopesStr.toJS,
        jsCallback,
      );

      return await completer.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          debugPrint('requestAuthCode timed out.');
          return null;
        },
      );
    } catch (e) {
      debugPrint('requestAuthCode exception: $e');
      return null;
    }
  }

  /// Vercel Serverless Function `/api/google/connect` 호출
  /// - authorization_code 교환 (redirectUri 지원)
  static Future<GoogleServerAuthResult?> exchangeAuthCode(String code, {String? redirectUri}) async {
    try {
      final bodyMap = <String, dynamic>{'code': code};
      if (redirectUri != null && redirectUri.isNotEmpty) {
        bodyMap['redirect_uri'] = redirectUri;
      } else {
        final origin = web.window.location.origin;
        final pathname = web.window.location.pathname;
        bodyMap['redirect_uri'] = origin + pathname;
      }

      final response = await web.window.fetch(
        '/api/google/connect'.toJS,
        web.RequestInit(
          method: 'POST',
          headers: web.Headers({'Content-Type': 'application/json'}.jsify() as JSObject),
          body: jsonEncode(bodyMap).toJS,
          credentials: 'include', // HttpOnly Cookie 저장을 위해 필수
        ),
      ).toDart;

      if (!response.ok) {
        debugPrint('exchangeAuthCode failed with status ${response.status}');
        return null;
      }

      final text = (await response.text().toDart).toDart;
      final map = jsonDecode(text) as Map<String, dynamic>;

      final accessToken = map['access_token'] as String?;
      final expiresIn = map['expires_in'] as int? ?? 3600;
      final encryptedRefreshToken = map['encrypted_refresh_token'] as String?;
      final userMap = map['user'] as Map<String, dynamic>?;

      if (accessToken == null || accessToken.isEmpty) {
        return null;
      }

      return GoogleServerAuthResult(
        accessToken: accessToken,
        expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
        encryptedRefreshToken: encryptedRefreshToken,
        userMap: userMap,
      );
    } catch (e) {
      debugPrint('exchangeAuthCode exception: $e');
      return null;
    }
  }

  /// Vercel Serverless Function `/api/google/token` 호출
  /// - 퍼스트 파티 HttpOnly 쿠키 또는 encryptedRefreshToken을 전송하여 새 access_token 갱신
  /// - 브라우저 쿠키 / ITP 제약 없이 100% 영구 동작
  static Future<GoogleServerAuthResult?> fetchFreshAccessToken({String? encryptedRefreshToken}) async {
    try {
      final bodyMap = <String, dynamic>{};
      if (encryptedRefreshToken != null) {
        bodyMap['encrypted_refresh_token'] = encryptedRefreshToken;
      }

      final response = await web.window.fetch(
        '/api/google/token'.toJS,
        web.RequestInit(
          method: 'POST',
          headers: web.Headers({'Content-Type': 'application/json'}.jsify() as JSObject),
          body: jsonEncode(bodyMap).toJS,
          credentials: 'include', // HttpOnly Cookie 전송을 위해 필수
        ),
      ).toDart;

      if (!response.ok) {
        debugPrint('fetchFreshAccessToken failed with status ${response.status}');
        return null;
      }

      final text = (await response.text().toDart).toDart;
      final map = jsonDecode(text) as Map<String, dynamic>;

      final accessToken = map['access_token'] as String?;
      final expiresIn = map['expires_in'] as int? ?? 3600;

      if (accessToken == null || accessToken.isEmpty) {
        return null;
      }

      return GoogleServerAuthResult(
        accessToken: accessToken,
        expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
      );
    } catch (e) {
      debugPrint('fetchFreshAccessToken exception: $e');
      return null;
    }
  }

  /// 연결 해제 시 서버 세션 쿠키 제거
  static Future<void> disconnectServerSession() async {
    try {
      await web.window.fetch(
        '/api/google/disconnect'.toJS,
        web.RequestInit(
          method: 'POST',
          credentials: 'include',
        ),
      ).toDart;
    } catch (e) {
      debugPrint('disconnectServerSession error: $e');
    }
  }

  static Future<void> startRedirectAuth({
    required String clientId,
    required List<String> scopes,
    String? loginHint,
  }) async {}

  static Future<dynamic> consumeRedirectResult() async => null;
}
