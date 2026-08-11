import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'desktop_google_auth_service.dart';
import 'google_session_storage.dart';

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

  final _userController = StreamController<GoogleAuthUser?>.broadcast();
  Stream<GoogleAuthUser?> get onCurrentUserChanged => _userController.stream;

  GoogleSignIn get _googleSignIn => GoogleSignIn(
        clientId: customClientId,
        scopes: _scopes,
      );

  GoogleAuthUser? get currentUser {
    if (!kIsWeb && (Platform.isLinux || Platform.isWindows)) {
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
      if (!kIsWeb && (Platform.isLinux || Platform.isWindows)) {
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
          token = authHeaders['Authorization']?.replaceAll('Bearer ', '') ?? '';
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
      if (!kIsWeb && (Platform.isLinux || Platform.isWindows)) {
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

          String token = sessionData?.accessToken ?? '';
          try {
            final authHeaders = await account.authHeaders;
            token = authHeaders['Authorization']?.replaceAll('Bearer ', '') ?? token;
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
      if (!kIsWeb && (Platform.isLinux || Platform.isWindows)) {
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

  /// googleapis 패키지에서 사용할 인증 헤더가 포함된 http.Client 객체 리턴
  Future<http.Client?> getAuthenticatedClient() async {
    if (!kIsWeb && (Platform.isLinux || Platform.isWindows)) {
      var desktopAcc = await _desktopAuth.loadSavedAccount();
      if (desktopAcc == null) return null;
      if (desktopAcc.isExpired && desktopAcc.refreshToken != null) {
        await _desktopAuth.refreshAccessToken();
        desktopAcc = _desktopAuth.currentAccount;
      }
      if (desktopAcc == null) return null;
      return _AuthenticatedClient(desktopAcc.authHeaders, http.Client());
    }

    // 웹/모바일 환경
    try {
      final account = _signedInAccount ?? _googleSignIn.currentUser ?? (await _googleSignIn.signInSilently());
      if (account != null) {
        final authHeaders = await account.authHeaders;
        final token = authHeaders['Authorization']?.replaceAll('Bearer ', '');
        if (token != null && token.isNotEmpty) {
          // 토큰 최신화 저장
          final currentUserObj = currentUser;
          if (currentUserObj != null) {
            await GoogleSessionStorage.saveSession(GoogleSessionData(
              id: currentUserObj.id,
              email: currentUserObj.email,
              displayName: currentUserObj.displayName,
              photoUrl: currentUserObj.photoUrl,
              accessToken: token,
              expiresAt: DateTime.now().add(const Duration(hours: 1)),
            ));
          }
        }
        return _AuthenticatedClient(authHeaders, http.Client());
      }
    } catch (e) {
      debugPrint('GoogleAuthService getAuthenticatedClient error: $e');
    }

    // 웹 세션 보관소(localStorage)의 Access Token 활용 복원
    final sessionData = await GoogleSessionStorage.loadSession();
    if (sessionData != null && sessionData.accessToken.isNotEmpty) {
      final isExpired = sessionData.expiresAt != null && DateTime.now().isAfter(sessionData.expiresAt!);
      if (isExpired) {
        // 만료된 경우 재로그인 / Silent auth 시도
        try {
          final account = await _googleSignIn.signInSilently();
          if (account != null) {
            final authHeaders = await account.authHeaders;
            return _AuthenticatedClient(authHeaders, http.Client());
          }
        } catch (_) {}
      } else {
        // 토큰이 유효한 경우 보관된 Access Token으로 인증 클라이언트 제공
        final headers = {'Authorization': 'Bearer ${sessionData.accessToken}'};
        return _AuthenticatedClient(headers, http.Client());
      }
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
