import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_identity_services_web/oauth2.dart';
import 'google_token_refresh_stub.dart';

/// Google Identity Services의 Token Client(웹 전용)를 이용해
/// 기존 동의/세션을 기반으로 access token을 조용히(silent) 재발급한다.
///
/// - 기존에 승인된 클라이언트 ID·스코프라면 팝업 없이 새 토큰을 받는다.
/// - 브라우저 세션이 만료됐거나 서드파티 쿠키가 차단된 환경에서는 실패할 수 있다.
///   (이 경우 [GoogleAuthService.reauthenticate]가 google_sign_in 계정 세션으로 폴백)
class GoogleTokenRefresher {
  /// 새 access token 발급을 시도하고, 실패하면 null을 반환한다.
  static Future<GoogleTokenRefreshResult?> refreshAccessToken({
    required String clientId,
    required List<String> scopes,
    String? loginHint,
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
        // callback으로 전달되지 않는 초기화 오류(invalid_client 등)는 즉시 폴백
        error_callback: (GoogleIdentityServicesError? error) {
          debugPrint('GoogleTokenRefresher: GIS error_callback: ${error?.type}');
          completeOnce(null);
        },
      ));

      tokenClient.requestAccessToken(OverridableTokenClientConfig(
        // 빈 prompt = 가능하면 UI 없이 조용히 재발급
        prompt: '',
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
}
