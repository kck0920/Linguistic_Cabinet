import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_identity_services_web/oauth2.dart';
import 'package:web/web.dart' as web;
import 'google_token_refresh_stub.dart';

/// Google Identity Services의 Token Client(웹 전용)를 이용해 access token을
/// 재발급한다.
///
/// - [interactive] == false: `prompt: ''` — 기존 동의/세션이 살아 있으면
///   팝업 없이 조용히(silent) 재발급한다 (데스크톱 Chrome 등).
/// - [interactive] == true: 사용자 제스처(동기화 버튼) 기반 호출. prompt를
///   지정하지 않아 세션이 있으면 조용히, 없으면 구글 계정 선택 팝업을 띄운다.
///   (모바일 브라우저는 silent iframe 쿠키가 차단돼 있어 팝업이 필수)
/// - 팝업 재인증이 실패하면 호출자가 [startRedirectAuth]로 페이지 리다이렉트
///   재인증에 폴백할 수 있다.
class GoogleTokenRefresher {
  /// 새 access token 발급을 시도하고, 실패하면 null을 반환한다.
  static Future<GoogleTokenRefreshResult?> refreshAccessToken({
    required String clientId,
    required List<String> scopes,
    String? loginHint,
    bool interactive = false,
  }) async {
    try {
      final completer = Completer<GoogleTokenRefreshResult?>();

      // callback / error_callback / timeout 중 하나만 완료되도록 보호
      void completeOnce(GoogleTokenRefreshResult? result) {
        if (!completer.isCompleted) {
          completer.complete(result);
        }
      }

      final tokenClient = oauth2.initTokenClient(TokenClientConfig(
        client_id: clientId,
        scope: scopes,
        callback: (TokenResponse response) {
          final error = response.error;
          if (error != null && error.isNotEmpty) {
            debugPrint('GoogleTokenRefresher: GIS error: $error');
            completeOnce(null);
            return;
          }
          final token = response.access_token;
          if (token == null || token.isEmpty || token == 'null') {
            completeOnce(null);
            return;
          }
          final expiresIn = response.expires_in;
          completeOnce(GoogleTokenRefreshResult(
            accessToken: token,
            expiresAt: expiresIn != null
                ? DateTime.now().add(Duration(seconds: expiresIn))
                : DateTime.now().add(const Duration(hours: 1)),
          ));
        },
        // callback으로 전달되지 않는 초기화 오류(invalid_client 등)는 즉시 폴백.
        // 주의: error.type getter는 매핑되지 않은 GIS 타입(popup_blocked 등)에서
        // throw할 수 있어 로그용으로만 안전하게 접근한다.
        error_callback: (GoogleIdentityServicesError? error) {
          String? typeDesc;
          try {
            typeDesc = error?.type.name;
          } catch (_) {}
          debugPrint('GoogleTokenRefresher: GIS error_callback: $typeDesc');
          completeOnce(null);
        },
      ));

      tokenClient.requestAccessToken(OverridableTokenClientConfig(
        // interactive: prompt 미지정(필요할 때만 팝업) / silent: 빈 prompt
        prompt: interactive ? null : '',
        login_hint: loginHint,
      ));

      return await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('GoogleTokenRefresher: timed out waiting for token.');
          completeOnce(null);
          return null;
        },
      );
    } catch (e) {
      debugPrint('GoogleTokenRefresher error: $e');
      return null;
    }
  }

  /// 팝업 재인증이 불가능한 브라우저(iOS Safari 등)에서 페이지 전체를
  /// 구글 OAuth(implicit flow)로 리다이렉트한다. 성공 시 Google이
  /// [redirect_uri](현재 페이지)로 되돌려 보내며, 복귀 후
  /// [consumeRedirectResult]가 fragment에서 토큰을 회수한다.
  static Future<void> startRedirectAuth({
    required String clientId,
    required List<String> scopes,
    String? loginHint,
  }) async {
    try {
      final currentHref = web.window.location.href;
      final redirectUri = Uri.parse(currentHref).replace(fragment: '').toString();
      final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'response_type': 'token',
        'scope': scopes.join(' '),
        'include_granted_scopes': 'true',
        'login_hint': ?loginHint,
      });
      // 참고: redirect_uri(현재 페이지 URL)는 Google Cloud Console의 OAuth
      // 클라이언트 'Authorized redirect URIs'에 정확히 등록돼 있어야 한다.
      // 미등록 시 Google이 redirect_uri_mismatch를 반환해 이 폴백은 실패한다
      // (팝업 경로는 JavaScript origin만 등록돼 있으면 동작).
      debugPrint('GoogleTokenRefresher: redirecting to Google auth...');
      web.window.location.assign(authUrl.toString());
    } catch (e) {
      debugPrint('GoogleTokenRefresher startRedirectAuth error: $e');
    }
  }

  /// 리다이렉트 복귀 시 URL fragment(#access_token=...)에서 토큰을 회수하고
  /// fragment를 URL에서 제거한다(리로드 시 재소비 방지). 토큰이 없으면 null.
  static Future<GoogleTokenRefreshResult?> consumeRedirectResult() async {
    try {
      final href = web.window.location.href;
      final hashIdx = href.indexOf('#');
      if (hashIdx < 0) return null;

      final params = Uri.splitQueryString(href.substring(hashIdx + 1));
      // OAuth 응답(access_token/error)이 아닌 fragment(예: hash 라우팅의 #/route)는
      // 건드리지 않는다 — 앱 라우트가 사라지는 것을 방지.
      final isOAuthResponse =
          params.containsKey('access_token') || params.containsKey('error');
      if (!isOAuthResponse) return null;

      if (params.containsKey('error')) {
        debugPrint('GoogleTokenRefresher: redirect error: ${params['error']}');
        _clearFragment(href);
        return null;
      }
      final token = params['access_token'];
      if (token == null || token.isEmpty || token == 'null') {
        _clearFragment(href);
        return null;
      }
      final expiresIn = int.tryParse(params['expires_in'] ?? '');
      final result = GoogleTokenRefreshResult(
        accessToken: token,
        expiresAt: expiresIn != null
            ? DateTime.now().add(Duration(seconds: expiresIn))
            : DateTime.now().add(const Duration(hours: 1)),
      );
      _clearFragment(href);
      return result;
    } catch (e) {
      debugPrint('GoogleTokenRefresher consumeRedirectResult error: $e');
      return null;
    }
  }

  /// URL fragment 제거 (history.replaceState로 현재 URL을 정리)
  static void _clearFragment(String href) {
    try {
      final clean = Uri.parse(href).replace(fragment: '').toString();
      web.window.history.replaceState(null, '', clean);
    } catch (e) {
      debugPrint('GoogleTokenRefresher _clearFragment error: $e');
    }
  }
}
