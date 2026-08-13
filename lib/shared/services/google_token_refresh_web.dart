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

class GoogleTokenRefresher {
  /// 웹: GIS initCodeClient 팝업을 통해 authorization_code를 수신한다.
  /// 사용자 클릭 핸들러 직후 호출하여 브라우저 팝업 차단을 방지한다.
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
  /// - authorization_code 교환
  /// - HttpOnly 쿠키(voca_session) 설정 및 encrypted_refresh_token, initial access_token 수신
  static Future<GoogleServerAuthResult?> exchangeAuthCode(String code) async {
    try {
      final response = await web.window.fetch(
        '/api/google/connect'.toJS,
        web.RequestInit(
          method: 'POST',
          headers: web.Headers({'Content-Type': 'application/json'}.jsify() as JSObject),
          body: jsonEncode({'code': code}).toJS,
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
