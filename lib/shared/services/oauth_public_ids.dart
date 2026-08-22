/// 커밋 가능한 공개(public) OAuth 식별자.
///
/// OAuth Client ID는 웹 번들에 그대로 포함되는 공개 값이므로 커밋해도 안전합니다.
/// 반면 데스크톱용 client secret 등 민감 값은 .gitignore된
/// `oauth_credentials.dart`(템플릿: `oauth_credentials.example.dart`)에서 관리합니다.
class OAuthPublicIds {
  OAuthPublicIds._();

  /// 웹(Google Identity Services) 및 GIS 플러그인 경로에서 사용하는
  /// OAuth Client ID.
  static const String webClientId =
      '1002909356316-llhqdfguevm9je83uhtdqblgm5621ra1.apps.googleusercontent.com';
}
