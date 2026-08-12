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
  }) async {
    debugPrint('GoogleTokenRefresher: Not supported on this platform.');
    return null;
  }
}
