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

/// GIS authorization_code 요청 결과.
///
/// [error]는 사용자가 팝업을 직접 닫거나 거부한 경우(취소)와 기술적 실패를
/// 구분할 때 사용한다. [userCancelled] == true이면 추가 폴백 프롬프트 없이
/// 로그인 시도를 조용히 종료하는 것이 UX상 올바르다.
class GoogleAuthCodeRequest {
  final String? code;
  final String? error;

  const GoogleAuthCodeRequest({this.code, this.error});

  bool get userCancelled {
    final e = (error ?? '').toLowerCase();
    return e.contains('popup_closed') ||
        e.contains('popup_failed_to_open') ||
        e.contains('access_denied') ||
        e.contains('dismissed');
  }
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
  ///
  /// [prompt]: 'consent'(기본 — refresh_token 발급 보장) 또는
  /// 'select_account'(기존 refresh_token이 살아있는 재로그인 시 동의 화면 생략).
  static Future<GoogleAuthCodeRequest> requestAuthCode({
    required String clientId,
    required List<String> scopes,
    String prompt = 'consent',
  }) async {
    debugPrint('GoogleTokenRefresher.requestAuthCode: Not supported on this platform.');
    return GoogleAuthCodeRequest(error: 'unsupported_platform');
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
