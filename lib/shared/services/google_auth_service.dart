import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'desktop_google_auth_service.dart';
import 'google_session_storage.dart';
import 'google_token_refresh.dart';
import 'oauth_public_ids.dart';

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

  /// Web/Desktop 환경용 OAuth Client ID (공개 값 — [OAuthPublicIds] 단일 소스)
  static String? customClientId = OAuthPublicIds.webClientId;

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

  /// 구글 로그인 시도 (Authorization Code Flow 및 GIS Token Client 2중 지원)
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

      // 웹 환경:
      if (_isWebAuth) {
        // 기존 세션에 유효한 refresh token이 있으면 select_account로 동의 화면 생략, 없으면 consent로 refresh token 발급 유도
        final existingSession = await GoogleSessionStorage.loadSession();
        final hasRefreshToken = existingSession?.encryptedRefreshToken != null &&
            existingSession!.encryptedRefreshToken!.isNotEmpty;
        final promptMode = hasRefreshToken ? 'select_account' : 'consent';

        // 1. Auth Code Flow + Serverless 시도
        final codeReq = await GoogleTokenRefresher.requestAuthCode(
          clientId: customClientId ?? '',
          scopes: _scopes,
          prompt: promptMode,
        );

        // 사용자가 팝업을 직접 닫거나 취소한 경우: 추가 프롬프트 없이 즉시 종료
        if (codeReq.userCancelled) {
          debugPrint('Google Sign-In cancelled by user.');
          return null;
        }

        final code = codeReq.code;
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
              encryptedRefreshToken: serverResult.encryptedRefreshToken ?? existingSession?.encryptedRefreshToken,
              expiresAt: serverResult.expiresAt,
            ));

            _userController.add(user);
            return user;
          }
        }

        // 사용자가 취소한 것이 아니라 서버리스 exchangeAuthCode가 기술적으로 실패한 경우에만 GIS Token Client 폴백 시도
        if (code != null && code.isNotEmpty) {
          final tokenResult = await GoogleTokenRefresher.requestAccessToken(
            clientId: customClientId ?? '',
            scopes: _scopes,
            prompt: 'select_account',
          );

          if (tokenResult != null && tokenResult.accessToken.isNotEmpty) {
            final userInfo = await GoogleTokenRefresher.fetchUserInfo(tokenResult.accessToken);
            final user = GoogleAuthUser(
              id: userInfo?['id'] as String? ?? 'user_${DateTime.now().millisecondsSinceEpoch}',
              email: userInfo?['email'] as String? ?? 'google_user@gmail.com',
              displayName: userInfo?['name'] as String?,
              photoUrl: userInfo?['picture'] as String?,
            );
            _savedWebUser = user;

            await GoogleSessionStorage.saveSession(GoogleSessionData(
              id: user.id,
              email: user.email,
              displayName: user.displayName,
              photoUrl: user.photoUrl,
              accessToken: tokenResult.accessToken,
              encryptedRefreshToken: existingSession?.encryptedRefreshToken,
              expiresAt: tokenResult.expiresAt,
            ));

            _userController.add(user);
            return user;
          }
        }

        return null;
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

  /// 기존 로그인 세션 조용히 복원 (팝업/네트워크 로그인 요청 절대 금지)
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

      // 세션 저장소(Dual Storage: localStorage + SQLite)에서 저장된 유저 정보 복원
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

        // 만약 토큰이 만료되었거나 만료 임박(5분 전) 상태라면 백그라운드로 미리 갱신 시도 (사용자 로그인 상태는 무조건 유지)
        if (_isWebAuth && _isExpiredSession(sessionData)) {
          unawaited(
            _refreshWebAccessToken(sessionData: sessionData, interactive: false)
                .catchError((e) {
              debugPrint('Background silent token refresh error: $e');
              return null;
            }),
          );
        }

        return user;
      }

      // 웹 모바일/리다이렉트 복귀 시 authorization_code가 수신된 경우에만 자동 토큰 교환
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

      return null;
    } catch (e) {
      debugPrint('Google Silent Sign-In Error: $e');
      return null;
    }
  }

  /// 로그아웃 (사용자가 명시적으로 '연결 해제' 버튼을 누른 경우에만 호출됨)
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

  Future<String?>? _inFlightWebRefresh;

  /// Web 토큰 갱신 (In-flight 락으로 동시 다중 호출 시 중복 팝업 및 중복 갱신 원천 차단):
  /// 1. Vercel Serverless Function (/api/google/token)으로 refresh_token 기반 갱신
  /// 2. 실패 시 브라우저 GIS Token Client (prompt: '') 로 백그라운드 무팝업 사일런트 갱신
  /// 3. [interactive] == true 이면 GIS Token Client (prompt: 'select_account') 로 팝업 재인증 갱신
  Future<String?> _refreshWebAccessToken({
    required GoogleSessionData sessionData,
    bool interactive = false,
  }) {
    final inFlight = _inFlightWebRefresh;
    if (inFlight != null) {
      debugPrint('_refreshWebAccessToken: Reusing in-flight refresh task.');
      return inFlight;
    }
    final future = _doRefreshWebAccessToken(
      sessionData: sessionData,
      interactive: interactive,
    );
    _inFlightWebRefresh = future;
    future.whenComplete(() => _inFlightWebRefresh = null);
    return future;
  }

  Future<String?> _doRefreshWebAccessToken({
    required GoogleSessionData sessionData,
    bool interactive = false,
  }) async {
    // 1단계: Vercel Serverless Function (/api/google/token)
    if (sessionData.encryptedRefreshToken != null) {
      try {
        final serverResult = await GoogleTokenRefresher.fetchFreshAccessToken(
          encryptedRefreshToken: sessionData.encryptedRefreshToken,
        );
        if (serverResult != null && serverResult.accessToken.isNotEmpty) {
          await GoogleSessionStorage.saveSession(GoogleSessionData(
            id: sessionData.id,
            email: sessionData.email,
            displayName: sessionData.displayName,
            photoUrl: sessionData.photoUrl,
            accessToken: serverResult.accessToken,
            encryptedRefreshToken: serverResult.encryptedRefreshToken ?? sessionData.encryptedRefreshToken,
            expiresAt: serverResult.expiresAt,
          ));
          debugPrint('Web token successfully refreshed via Serverless API');
          return serverResult.accessToken;
        }
      } catch (e) {
        debugPrint('Serverless token refresh error: $e');
      }
    }

    // 2단계: 브라우저 GIS Token Client 사일런트 갱신 (prompt: '')
    if (customClientId != null) {
      try {
        final clientResult = await GoogleTokenRefresher.requestAccessToken(
          clientId: customClientId!,
          scopes: _scopes,
          prompt: '',
        );
        if (clientResult != null && clientResult.accessToken.isNotEmpty) {
          await GoogleSessionStorage.saveSession(GoogleSessionData(
            id: sessionData.id,
            email: sessionData.email,
            displayName: sessionData.displayName,
            photoUrl: sessionData.photoUrl,
            accessToken: clientResult.accessToken,
            encryptedRefreshToken: sessionData.encryptedRefreshToken,
            expiresAt: clientResult.expiresAt,
          ));
          debugPrint('Web token successfully refreshed via GIS Silent Token Client');
          return clientResult.accessToken;
        }
      } catch (e) {
        debugPrint('GIS silent token refresh error: $e');
      }
    }

    // 3단계: 인터랙티브 모드 (사용자가 '지금 동기화' 버튼을 눌렀을 때만 팝업 허용)
    if (interactive && customClientId != null) {
      try {
        final clientResult = await GoogleTokenRefresher.requestAccessToken(
          clientId: customClientId!,
          scopes: _scopes,
          prompt: 'select_account',
        );
        if (clientResult != null && clientResult.accessToken.isNotEmpty) {
          await GoogleSessionStorage.saveSession(GoogleSessionData(
            id: sessionData.id,
            email: sessionData.email,
            displayName: sessionData.displayName,
            photoUrl: sessionData.photoUrl,
            accessToken: clientResult.accessToken,
            encryptedRefreshToken: sessionData.encryptedRefreshToken,
            expiresAt: clientResult.expiresAt,
          ));
          debugPrint('Web token successfully refreshed via GIS Interactive Token Client');
          return clientResult.accessToken;
        }
      } catch (e) {
        debugPrint('GIS interactive token refresh error: $e');
      }
    }

    return null;
  }

  /// 토큰 만료 시 재인증 및 새 클라이언트 반환
  /// (사용자가 '연결 해제'를 누르기 전까지는 갱신 실패 시에도 세션을 삭제하지 않음)
  Future<http.Client?> reauthenticate({bool interactive = false}) async {
    if (_isDesktopAuth) {
      return _desktopAuthenticatedClient();
    }

    if (_isWebAuth) {
      final sessionData = await GoogleSessionStorage.loadSession();
      if (sessionData != null) {
        final freshToken = await _refreshWebAccessToken(
          sessionData: sessionData,
          interactive: interactive,
        );
        if (freshToken != null && freshToken.isNotEmpty) {
          final headers = {'Authorization': 'Bearer $freshToken'};
          return _AuthenticatedClient(headers, http.Client());
        }
      }
    }

    // 폴백: google_sign_in
    try {
      final account = _signedInAccount ?? _googleSignIn.currentUser;
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

    // 토큰 갱신에 실패하더라도 사용자가 '연결 해제'를 누르기 전까지는 세션을 절대 파기하지 않는다.
    debugPrint('GoogleAuthService reauthenticate: Token refresh failed, preserving user session.');
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

        // 2) 만료되었을 경우 3중 갱신 시도
        if (_isWebAuth) {
          final freshToken = await _refreshWebAccessToken(
            sessionData: sessionData,
            interactive: interactive,
          );
          if (freshToken != null && freshToken.isNotEmpty) {
            final headers = {'Authorization': 'Bearer $freshToken'};
            return _AuthenticatedClient(headers, http.Client());
          }
        }
      }

      // 3) google_sign_in 계정 세션 폴백
      final account = _signedInAccount ?? _googleSignIn.currentUser;
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
