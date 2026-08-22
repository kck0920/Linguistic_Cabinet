/// Google OAuth 자격증명 템플릿 (커밋 가능)
///
/// 실제 파일은 gitignore 대상입니다. 아래 명령으로 복사한 뒤 값을 채우세요:
///   cp lib/shared/services/oauth_credentials.example.dart \
///      lib/shared/services/oauth_credentials.dart
class OAuthCredentials {
  /// 필수 — 데스크톱 Google 로그인용 OAuth Client ID
  static const String clientId = 'YOUR_DESKTOP_OAUTH_CLIENT_ID.apps.googleusercontent.com';

  /// 선택 — 설치형 앱은 PKCE만으로 안전하며(RFC 8252), 채우면 함께 전송됨
  static const String clientSecret = 'YOUR_DESKTOP_OAUTH_CLIENT_SECRET';
}
