import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'desktop_google_auth_service.dart';

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

      final account = await _googleSignIn.signInSilently();
      if (account != null) {
        _signedInAccount = account;
        final user = GoogleAuthUser(
          id: account.id,
          email: account.email,
          displayName: account.displayName,
          photoUrl: account.photoUrl,
        );
        _userController.add(user);
        return user;
      }
      return currentUser;
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

      _signedInAccount = null;
      await _googleSignIn.signOut();
      _userController.add(null);
    } catch (e) {
      debugPrint('Google Sign-Out Error: $e');
      _signedInAccount = null;
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

    final account = _signedInAccount ?? _googleSignIn.currentUser ?? (await _googleSignIn.signInSilently());
    if (account == null) return null;

    final authHeaders = await account.authHeaders;
    return _AuthenticatedClient(authHeaders, http.Client());
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
