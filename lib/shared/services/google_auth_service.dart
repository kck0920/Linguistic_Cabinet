import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'desktop_google_auth_service.dart';
import 'google_session_storage.dart';
import 'google_token_refresh.dart';

/// 토큰 재발급 핸들러 시그니처 (웹: GIS Token Client, 테스트: 주입 가능)
typedef TokenRefreshHandler = Future<GoogleTokenRefreshResult?> Function({
  required String clientId,
  required List<String> scopes,
  String? loginHint,
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

  /// 테스트에서 토큰 재발급 동작을 주입하는 시임 (null이면 실제 구현 사용)
  @visibleForTesting
  TokenRefreshHandler? tokenRefreshHandler;

  /// 테스트에서 VM에서도 웹 인증 경로를 강제하는 시임
  @visibleForTesting
  bool forceWebAuthPath = false;

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

  /// 구글 로그인 시도 (플랫폼 자동 판단)
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

      // 웹/모바일 환경: 세션 저장소에서 저장된 유저 정보 및 토큰 복원
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

  /// 저장된 access token이 실제 사용 가능한 값인지 검사
  bool _isUsableToken(String? token) =>
      token != null && token.isNotEmpty && token != 'null';

  /// 저장된 세션 토큰이 만료되었는지 검사 (안전 여유 5분: 만료 직전에도 재발급)
  bool _isExpiredSession(GoogleSessionData session) {
    final expiresAt = session.expiresAt;
    if (expiresAt == null) return true;
    return DateTime.now().isAfter(expiresAt.subtract(const Duration(minutes: 5)));
  }

  /// 웹 전용: GIS Token Client로 새 access token을 조용히 발급받아 세션에 저장한다.
  /// 실패 시 null. (테스트에서는 [tokenRefreshHandler]로 대체 가능)
  Future<http.Client?> _silentWebTokenRefresh(GoogleSessionData session) async {
    final handler = tokenRefreshHandler ?? GoogleTokenRefresher.refreshAccessToken;
    final result = await handler(
      clientId: customClientId ?? '',
      scopes: _scopes,
      loginHint: session.email,
    );
    if (result == null) return null;

    await GoogleSessionStorage.saveSession(GoogleSessionData(
      id: session.id,
      email: session.email,
      displayName: session.displayName,
      photoUrl: session.photoUrl,
      accessToken: result.accessToken,
      expiresAt: result.expiresAt,
    ));
    final headers = {'Authorization': 'Bearer ${result.accessToken}'};
    return _AuthenticatedClient(headers, http.Client());
  }

  /// 인증 실패(401 등)가 발생했을 때 새 토큰으로 재인증을 시도하고,
  /// 성공 시 새 인증 클라이언트를 반환한다. 실패 시 null.
  Future<http.Client?> reauthenticate() async {
    if (_isDesktopAuth) {
      return _desktopAuthenticatedClient();
    }

    // 웹: GIS Token Client로 조용한 재발급 우선 시도
    if (_isWebAuth) {
      final sessionData = await GoogleSessionStorage.loadSession();
      if (sessionData != null) {
        final client = await _silentWebTokenRefresh(sessionData);
        if (client != null) return client;
      }
      // GIS 재발급이 실패한 상황에서 OneTap 재인증은 거의 실패하고
      // 예기치 않은 UI를 띄울 수 있으므로, 메모리에 방금 로그인한
      // 계정이 있는 경우에만 google_sign_in 폴백을 시도한다.
      if (_signedInAccount == null) return null;
    }

    // 모바일 및 웹 폴백: google_sign_in 계정 세션 재사용
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
    return null;
  }

  /// 데스크톱(리눅스/윈도우): 저장된 계정으로 인증 클라이언트 생성
  /// (만료 시 refresh token으로 자동 갱신)
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
  Future<http.Client?> getAuthenticatedClient() async {
    if (_isDesktopAuth) {
      return _desktopAuthenticatedClient();
    }

    // 웹/모바일 환경
    try {
      // 1) 저장된 세션의 access token이 아직 유효하면 그대로 사용
      //    (토큰 갱신 불필요 — 페이지 새로고침 후에도 안정적으로 동작)
      final sessionData = await GoogleSessionStorage.loadSession();
      if (sessionData != null) {
        final tokenUsable = _isUsableToken(sessionData.accessToken);
        if (tokenUsable && !_isExpiredSession(sessionData)) {
          final headers = {'Authorization': 'Bearer ${sessionData.accessToken}'};
          return _AuthenticatedClient(headers, http.Client());
        }
        // 2) 만료/무효 토큰 → 재발급 시도
        //    (웹: GIS Token Client silent 갱신, 모바일: 곧바로 계정 경로 폴백)
        if (_isWebAuth) {
          final refreshed = await _silentWebTokenRefresh(sessionData);
          if (refreshed != null) return refreshed;
        }
      }

      // 3) google_sign_in 계정 세션 기반 폴백
      final account = _signedInAccount ??
          _googleSignIn.currentUser ??
          (await _googleSignIn.signInSilently());
      if (account != null) {
        final authHeaders = await account.authHeaders;
        final token = authHeaders['Authorization']?.replaceAll('Bearer ', '');
        if (_isUsableToken(token)) {
          // 토큰 최신화 저장
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
