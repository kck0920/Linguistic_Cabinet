import 'package:flutter/foundation.dart';

/// GIS(Google Identity Services) Token Client 재발급 결과
class GoogleTokenRefreshResult {
  final String accessToken;
  final DateTime expiresAt;

  GoogleTokenRefreshResult({required this.accessToken, required this.expiresAt});
}

/// 웹 외 플랫폼용 토큰 갱신자 (미지원 — null 반환)
class GoogleTokenRefresher {
  static Future<GoogleTokenRefreshResult?> refreshAccessToken({
    required String clientId,
    required List<String> scopes,
    String? loginHint,
    bool interactive = false,
  }) async {
    debugPrint('GoogleTokenRefresher: Not supported on this platform.');
    return null;
  }

  /// 웹: 팝업 재인증이 불가능한 브라우저에서 페이지 전체를 구글 OAuth로
  /// 리다이렉트한다. (그 외 플랫폼: 무동작)
  static Future<void> startRedirectAuth({
    required String clientId,
    required List<String> scopes,
    String? loginHint,
  }) async {}

  /// 웹: 리다이렉트 복귀 시 URL fragment에서 access token을 회수한다.
  /// (그 외 플랫폼: 항상 null)
  static Future<GoogleTokenRefreshResult?> consumeRedirectResult() async => null;
}
