import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'desktop_google_auth_service.dart';
import 'google_session_storage.dart';
import 'google_token_refresh.dart';

typedef TokenRefreshHandler = Future<GoogleTokenRefreshResult?> Function({
  required String clientId,
  required List<String> scopes,
  String? loginHint,
  bool interactive,
});

final googleUserProvider = StateNotifierProvider<GoogleUserNotifier, AsyncValue<GoogleAuthUser?>>((ref) {
  return GoogleUserNotifier();
});

class GoogleUserNotifier extends StateNotifier<AsyncValue<GoogleAuthUser?>> {
  GoogleUserNotifier() : super(const AsyncValue.loading()) {
    init();
  }

  Future<void> init() async {
    try {
      final user = await GoogleAuthService().signInSilently();
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<GoogleAuthUser?> signIn() async {
    state = const AsyncValue.loading();
    try {
      final user = await GoogleAuthService().signIn();
      state = AsyncValue.data(user);
      return user;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      await GoogleAuthService().signOut();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void refreshState() async {
    final user = await GoogleAuthService().signInSilently();
    state = AsyncValue.data(user);
  }
}

class GoogleAuthUser {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;

  GoogleAuthUser({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
  });
}

class GoogleAuthService {
  static final GoogleAuthService _instance = GoogleAuthService._internal();
  factory GoogleAuthService() => _instance;
  GoogleAuthService._internal();

  static const List<String> _scopes = [
    'email',
    'https://www.googleapis.com/auth/drive.appdata',
  ];

  /// Web/Desktop 환경용 OAuth Client ID
  static String? customClientId = '1002909356316-llhqdfguevm9je83uhtdqblgm5621ra1.apps.googleusercontent.com';

  GoogleSignInAccount? _signedInAccount;
  GoogleAuthUser? _savedWebUser;
  final DesktopGoogleAuthService _desktopAuth = DesktopGoogleAuthService();

  @visibleForTesting
  TokenRefreshHandler? tokenRefreshHandler;

  @visibleForTesting
  bool forceWebAuthPath = false;

  @visibleForTesting
  static bool suppressInteractiveReauth = false;

  bool get _isDesktopAuth =>
      !kIsWeb && (Platform.isLinux || Platform.isWindows) && !forceWebAuthPath;

  bool get _isWebAuth => kIsWeb || forceWebAuthPath;

  final _userController = StreamController<GoogleAuthUser?>.broadcast();
  Stream<GoogleAuthUser?> get onCurrentUserChanged => _userController.stream;

  GoogleSignIn get _googleSignIn => GoogleSignIn(
        clientId: customClientId,
        scopes: _scopes,
      );

  GoogleAuthUser? get currentUser {
    if (_isDesktopAuth) {
      final desktopAcc = _desktopAuth.currentAccount;
      if (desktopAcc == null) return null;
      return GoogleAuthUser(
        id: desktopAcc.id,
        email: desktopAcc.email,
        displayName: desktopAcc.displayName,
        photoUrl: desktopAcc.photoUrl,
      );
    }

    if (_savedWebUser != null) {
      return _savedWebUser;
    }

    final acc = _signedInAccount ?? _googleSignIn.currentUser;
    if (acc == null) return null;
    return GoogleAuthUser(
      id: acc.id,
      email: acc.email,
      displayName: acc.displayName,
      photoUrl: acc.photoUrl,
    );
  }

  /// 구글 로그인 시도 (Authorization Code Flow + Vercel Serverless Function)
  Future<GoogleAuthUser?> signIn() async {
    try {
      if (_isDesktopAuth) {
        final desktopAcc = await _desktopAuth.signIn();
        if (desktopAcc != null) {
          final user = GoogleAuthUser(
            id: desktopAcc.id,
            email: desktopAcc.email,
            displayName: desktopAcc.displayName,
            photoUrl: desktopAcc.photoUrl,
          );
          _userController.add(user);
          return user;
        }
        return null;
      }

      // 웹 환경: Authorization Code Flow (Serverless Token Exchange & Refresh Token 보관)
      if (_isWebAuth) {
        final code = await GoogleTokenRefresher.requestAuthCode(
          clientId: customClientId ?? '',
          scopes: _scopes,
        );

        if (code != null && code.isNotEmpty) {
          final serverResult = await GoogleTokenRefresher.exchangeAuthCode(code);
          if (serverResult != null) {
            final userMap = serverResult.userMap;
            final user = GoogleAuthUser(
              id: userMap?['id'] as String? ?? 'user_${DateTime.now().millisecondsSinceEpoch}',
              email: userMap?['email'] as String? ?? 'google_user@gmail.com',
              displayName: userMap?['name'] as String?,
              photoUrl: userMap?['picture'] as String?,
            );
            _savedWebUser = user;

            await GoogleSessionStorage.saveSession(GoogleSessionData(
              id: user.id,
              email: user.email,
              displayName: user.displayName,
              photoUrl: user.photoUrl,
              accessToken: serverResult.accessToken,
              encryptedRefreshToken: serverResult.encryptedRefreshToken,
              expiresAt: serverResult.expiresAt,
            ));

            _userController.add(user);
            return user;
          }
        }
      }

      // 모바일 / 웹 폴백: google_sign_in
      final account = await _googleSignIn.signIn();
      if (account != null) {
        _signedInAccount = account;
        final user = GoogleAuthUser(
          id: account.id,
          email: account.email,
          displayName: account.displayName,
          photoUrl: account.photoUrl,
        );
        _savedWebUser = user;

        String token = '';
        try {
          final authHeaders = await account.authHeaders;
          final candidate = authHeaders['Authorization']?.replaceAll('Bearer ', '');
          if (_isUsableToken(candidate)) {
            token = candidate!;
          }
        } catch (e) {
          debugPrint('Error getting web auth headers: $e');
        }

        await GoogleSessionStorage.saveSession(GoogleSessionData(
          id: user.id,
          email: user.email,
          displayName: user.displayName,
          photoUrl: user.photoUrl,
          accessToken: token,
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ));
        _userController.add(user);
        return user;
      }
      return null;
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      rethrow;
    }
  }

  /// 기존 로그인 세션 조용히 복원
  Future<GoogleAuthUser?> signInSilently() async {
    try {
      if (_isDesktopAuth) {
        final desktopAcc = await _desktopAuth.loadSavedAccount();
        if (desktopAcc != null) {
          final user = GoogleAuthUser(
            id: desktopAcc.id,
            email: desktopAcc.email,
            displayName: desktopAcc.displayName,
            photoUrl: desktopAcc.photoUrl,
          );
          _userController.add(user);
          return user;
        }
        return null;
      }

      // 세션 저장소에서 저장된 유저 정보 복원
      final sessionData = await GoogleSessionStorage.loadSession();
      if (sessionData != null) {
        final user = GoogleAuthUser(
          id: sessionData.id,
          email: sessionData.email,
          displayName: sessionData.displayName,
          photoUrl: sessionData.photoUrl,
        );
        _savedWebUser = user;
        _userController.add(user);
      }

      // 웹 모바일/리다이렉트 복귀 시 authorization_code가 수신된 경우 자동 토큰 교환
      if (_isWebAuth) {
        final redirectCode = GoogleTokenRefresher.consumeRedirectCode();
        if (redirectCode != null && redirectCode.isNotEmpty) {
          final serverResult = await GoogleTokenRefresher.exchangeAuthCode(redirectCode);
          if (serverResult != null) {
            final userMap = serverResult.userMap;
            final user = GoogleAuthUser(
              id: userMap?['id'] as String? ?? 'user_${DateTime.now().millisecondsSinceEpoch}',
              email: userMap?['email'] as String? ?? 'google_user@gmail.com',
              displayName: userMap?['name'] as String?,
              photoUrl: userMap?['picture'] as String?,
            );
            _savedWebUser = user;

            await GoogleSessionStorage.saveSession(GoogleSessionData(
              id: user.id,
              email: user.email,
              displayName: user.displayName,
              photoUrl: user.photoUrl,
              accessToken: serverResult.accessToken,
              encryptedRefreshToken: serverResult.encryptedRefreshToken,
              expiresAt: serverResult.expiresAt,
            ));

            _userController.add(user);
            return user;
          }
        }
      }

      try {
        final account = await _googleSignIn.signInSilently();
        if (account != null) {
          _signedInAccount = account;
          final user = GoogleAuthUser(
            id: account.id,
            email: account.email,
            displayName: account.displayName,
            photoUrl: account.photoUrl,
          );
          _savedWebUser = user;

          String token = sessionData != null && _isUsableToken(sessionData.accessToken)
              ? sessionData.accessToken
              : '';
          try {
            final authHeaders = await account.authHeaders;
            final candidate = authHeaders['Authorization']?.replaceAll('Bearer ', '');
            if (_isUsableToken(candidate)) {
              token = candidate!;
            }
          } catch (_) {}

          await GoogleSessionStorage.saveSession(GoogleSessionData(
            id: user.id,
            email: user.email,
            displayName: user.displayName,
            photoUrl: user.photoUrl,
            accessToken: token,
            encryptedRefreshToken: sessionData?.encryptedRefreshToken,
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
          ));
          _userController.add(user);
          return user;
        }
      } catch (e) {
        debugPrint('Google Sign In Web Silent Error: $e');
      }

      return _savedWebUser ?? currentUser;
    } catch (e) {
      debugPrint('Google Silent Sign-In Error: $e');
      return currentUser;
    }
  }

  /// 로그아웃
  Future<void> signOut() async {
    try {
      if (_isDesktopAuth) {
        await _desktopAuth.signOut();
        _userController.add(null);
        return;
      }

      if (_isWebAuth) {
        await GoogleTokenRefresher.disconnectServerSession();
      }

      _savedWebUser = null;
      _signedInAccount = null;
      await GoogleSessionStorage.clearSession();
      await _googleSignIn.signOut();
      _userController.add(null);
    } catch (e) {
      debugPrint('Google Sign-Out Error: $e');
      _savedWebUser = null;
      _signedInAccount = null;
      await GoogleSessionStorage.clearSession();
      _userController.add(null);
    }
  }

  bool _isUsableToken(String? token) =>
      token != null && token.isNotEmpty && token != 'null';

  bool _isExpiredSession(GoogleSessionData session) {
    final expiresAt = session.expiresAt;
    if (expiresAt == null) return true;
    return DateTime.now().isAfter(expiresAt.subtract(const Duration(minutes: 5)));
  }

  Future<void> persistAccessToken(String token, DateTime expiresAt) async {}

  /// 디버깅 / 테스트용: 현재 세션의 access token을 임의로 만료 시킴
  Future<void> forceExpireAccessToken() async {
    final session = await GoogleSessionStorage.loadSession();
    if (session != null) {
      await GoogleSessionStorage.saveSession(GoogleSessionData(
        id: session.id,
        email: session.email,
        displayName: session.displayName,
        photoUrl: session.photoUrl,
        accessToken: 'EXPIRED_TEST_TOKEN',
        encryptedRefreshToken: session.encryptedRefreshToken,
        expiresAt: DateTime.now().subtract(const Duration(minutes: 10)),
      ));
      debugPrint('GoogleAuthService: Access token forced to expired state for testing.');
    }
  }

  /// 토큰 만료 시 Vercel Serverless API (/api/google/token)를 호출하여
  /// 서버 사이드 refresh_token으로 새 access_token을 0.1초 만에 갱신받는다.
  /// (Safari ITP / 크로스사이트 쿠키 제한과 100% 무관하게 영구 작동)
  Future<http.Client?> reauthenticate({bool interactive = false}) async {
    if (_isDesktopAuth) {
      return _desktopAuthenticatedClient();
    }

    if (_isWebAuth) {
      final sessionData = await GoogleSessionStorage.loadSession();
      if (sessionData != null) {
        final serverResult = await GoogleTokenRefresher.fetchFreshAccessToken(
          encryptedRefreshToken: sessionData.encryptedRefreshToken,
        );
        if (serverResult != null) {
          await GoogleSessionStorage.saveSession(GoogleSessionData(
            id: sessionData.id,
            email: sessionData.email,
            displayName: sessionData.displayName,
            photoUrl: sessionData.photoUrl,
            accessToken: serverResult.accessToken,
            encryptedRefreshToken: sessionData.encryptedRefreshToken,
            expiresAt: serverResult.expiresAt,
          ));
          final headers = {'Authorization': 'Bearer ${serverResult.accessToken}'};
          return _AuthenticatedClient(headers, http.Client());
        }
      }
    }

    // 폴백: google_sign_in
    try {
      final account = _signedInAccount ??
          _googleSignIn.currentUser ??
          (await _googleSignIn.signInSilently());
      if (account != null) {
        final authHeaders = await account.authHeaders;
        final token = authHeaders['Authorization']?.replaceAll('Bearer ', '');
        if (_isUsableToken(token)) {
          final currentUserObj = currentUser;
          if (currentUserObj != null) {
            await GoogleSessionStorage.saveSession(GoogleSessionData(
              id: currentUserObj.id,
              email: currentUserObj.email,
              displayName: currentUserObj.displayName,
              photoUrl: currentUserObj.photoUrl,
              accessToken: token!,
              expiresAt: DateTime.now().add(const Duration(hours: 1)),
            ));
          }
          return _AuthenticatedClient(authHeaders, http.Client());
        }
      }
    } catch (e) {
      debugPrint('GoogleAuthService reauthenticate error: $e');
    }

    // 만약 invalid_grant 등 모든 토큰 갱신에 실패한 경우 사용자 재로그인 유도
    await signOut();
    return null;
  }

  Future<http.Client?> _desktopAuthenticatedClient() async {
    try {
      var desktopAcc = await _desktopAuth.loadSavedAccount();
      if (desktopAcc == null) return null;
      if (desktopAcc.isExpired && desktopAcc.refreshToken != null) {
        await _desktopAuth.refreshAccessToken();
        desktopAcc = _desktopAuth.currentAccount;
      }
      if (desktopAcc == null) return null;
      return _AuthenticatedClient(desktopAcc.authHeaders, http.Client());
    } catch (e) {
      debugPrint('GoogleAuthService desktop auth client error: $e');
      return null;
    }
  }

  /// googleapis 패키지에서 사용할 인증 헤더가 포함된 http.Client 객체 리턴
  Future<http.Client?> getAuthenticatedClient({bool interactive = false}) async {
    if (_isDesktopAuth) {
      return _desktopAuthenticatedClient();
    }

    try {
      final sessionData = await GoogleSessionStorage.loadSession();
      if (sessionData != null) {
        final tokenUsable = _isUsableToken(sessionData.accessToken);
        // 1) 토큰이 아직 유효하면 바로 반환
        if (tokenUsable && !_isExpiredSession(sessionData)) {
          final headers = {'Authorization': 'Bearer ${sessionData.accessToken}'};
          return _AuthenticatedClient(headers, http.Client());
        }

        // 2) 만료되었을 경우 Vercel Serverless Function (/api/google/token)으로 갱신 시도
        if (_isWebAuth) {
          final serverResult = await GoogleTokenRefresher.fetchFreshAccessToken(
            encryptedRefreshToken: sessionData.encryptedRefreshToken,
          );
          if (serverResult != null) {
            await GoogleSessionStorage.saveSession(GoogleSessionData(
              id: sessionData.id,
              email: sessionData.email,
              displayName: sessionData.displayName,
              photoUrl: sessionData.photoUrl,
              accessToken: serverResult.accessToken,
              encryptedRefreshToken: sessionData.encryptedRefreshToken,
              expiresAt: serverResult.expiresAt,
            ));
            final headers = {'Authorization': 'Bearer ${serverResult.accessToken}'};
            return _AuthenticatedClient(headers, http.Client());
          }
        }
      }

      // 3) google_sign_in 계정 세션 폴백
      final account = _signedInAccount ??
          _googleSignIn.currentUser ??
          (await _googleSignIn.signInSilently());
      if (account != null) {
        final authHeaders = await account.authHeaders;
        final token = authHeaders['Authorization']?.replaceAll('Bearer ', '');
        if (_isUsableToken(token)) {
          final currentUserObj = currentUser;
          if (currentUserObj != null) {
            await GoogleSessionStorage.saveSession(GoogleSessionData(
              id: currentUserObj.id,
              email: currentUserObj.email,
              displayName: currentUserObj.displayName,
              photoUrl: currentUserObj.photoUrl,
              accessToken: token!,
              expiresAt: DateTime.now().add(const Duration(hours: 1)),
            ));
          }
          return _AuthenticatedClient(authHeaders, http.Client());
        }
      }
    } catch (e) {
      debugPrint('GoogleAuthService getAuthenticatedClient error: $e');
    }

    return null;
  }
}

class _AuthenticatedClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client;

  _AuthenticatedClient(this._headers, this._client);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }

  @override
  void close() {
    _client.close();
  }
}
