import 'package:flutter/foundation.dart';

class GoogleTokenRefreshResult {
  final String accessToken;
  final DateTime expiresAt;

  GoogleTokenRefreshResult({required this.accessToken, required this.expiresAt});
}

class GoogleServerAuthResult {
  final String accessToken;
  final DateTime expiresAt;
  final String? encryptedRefreshToken;
  final Map<String, dynamic>? userMap;

  GoogleServerAuthResult({
    required this.accessToken,
    required this.expiresAt,
    this.encryptedRefreshToken,
    this.userMap,
  });
}

class GoogleTokenRefresher {
  static Future<GoogleTokenRefreshResult?> refreshAccessToken({
    required String clientId,
    required List<String> scopes,
    String? loginHint,
    bool interactive = false,
  }) async => null;

  static String? consumeRedirectCode() => null;

  /// 웹: GIS initCodeClient 팝업을 통해 authorization_code를 수신한다.
  static Future<String?> requestAuthCode({
    required String clientId,
    required List<String> scopes,
  }) async {
    debugPrint('GoogleTokenRefresher.requestAuthCode: Not supported on this platform.');
    return null;
  }

  /// Vercel Serverless Function `/api/google/connect`로 authorization_code를 전달하여
  /// 세션 쿠키/암호화 토큰 및 초기 access_token을 받는다.
  static Future<GoogleServerAuthResult?> exchangeAuthCode(String code, {String? redirectUri}) async {
    debugPrint('GoogleTokenRefresher.exchangeAuthCode: Not supported on this platform.');
    return null;
  }

  /// Vercel Serverless Function `/api/google/token`으로 서버 세션 쿠키(또는 암호화 토큰)를 검증하여
  /// 새 access_token을 갱신받는다. (100% 서버-대-서버 OAuth Refresh Token 갱신)
  static Future<GoogleServerAuthResult?> fetchFreshAccessToken({String? encryptedRefreshToken}) async {
    debugPrint('GoogleTokenRefresher.fetchFreshAccessToken: Not supported on this platform.');
    return null;
  }

  static Future<GoogleTokenRefreshResult?> requestAccessToken({
    required String clientId,
    required List<String> scopes,
    String prompt = '',
  }) async => null;

  static Future<Map<String, dynamic>?> fetchUserInfo(String accessToken) async => null;

  static Future<void> disconnectServerSession() async {}

  static Future<void> startRedirectAuth({
    required String clientId,
    required List<String> scopes,
    String? loginHint,
  }) async {}

  static Future<dynamic> consumeRedirectResult() async => null;
}
