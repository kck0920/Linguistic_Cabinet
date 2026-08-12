import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:linguistic_cabinet/shared/services/google_auth_service.dart';
import 'package:linguistic_cabinet/shared/services/google_session_storage.dart';
import 'package:linguistic_cabinet/shared/services/google_token_refresh.dart';

/// 테스트 범위:
/// 웹에서 access token이 만료되면 재발급되어 이후 동기화가 유효 토큰을 쓰는
/// 흐름을 검증한다. 실제 Drive API 호출(googleapis·네트워크)은 단위 테스트
/// 범위 밖이므로, "동기화 성공"은 ① 재발급 핸들러가 호출되고 ② 새 토큰으로
/// 세션이 갱신되어 ③ 인증 클라이언트가 반환된다는 사실로 간접 검증한다.
///(반환 클라이언트 내부의 Bearer 헤더는 네트워크 없이 접근 불가)

/// path_provider 경로를 임시 디렉토리로 대체 — 세션 저장소(stub)를 테스트에서
/// 실제 파일 I/O로 사용할 수 있게 한다.
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.path);
  final String path;

  @override
  Future<String?> getApplicationSupportPath() async => path;
}

/// 토큰 재발급 핸들러 가짜 — 호출 인자를 기록하고 주입된 결과를 반환한다.
class _FakeTokenRefresher {
  _FakeTokenRefresher(this.result);

  final GoogleTokenRefreshResult? result;
  final List<
      ({
        String clientId,
        List<String> scopes,
        String? loginHint,
        bool interactive,
      })> calls = [];

  Future<GoogleTokenRefreshResult?> call({
    required String clientId,
    required List<String> scopes,
    String? loginHint,
    bool interactive = false,
  }) async {
    calls.add((
      clientId: clientId,
      scopes: List.unmodifiable(scopes),
      loginHint: loginHint,
      interactive: interactive,
    ));
    return result;
  }
}

GoogleSessionData _session({
  required String token,
  required DateTime expiresAt,
  String email = 'user@example.com',
}) {
  return GoogleSessionData(
    id: 'user-1',
    email: email,
    displayName: 'User',
    accessToken: token,
    expiresAt: expiresAt,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late PathProviderPlatform originalPathProvider;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('voca_google_auth_test');
    originalPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
  });

  tearDownAll(() {
    PathProviderPlatform.instance = originalPathProvider;
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    final auth = GoogleAuthService();
    auth.forceWebAuthPath = true;
    auth.tokenRefreshHandler = null;
    await GoogleSessionStorage.clearSession();
  });

  tearDown(() {
    final auth = GoogleAuthService();
    auth.forceWebAuthPath = false;
    auth.tokenRefreshHandler = null;
  });

  group('GoogleAuthService.getAuthenticatedClient — 토큰 만료 → 재발급', () {
    test('만료된 토큰이면 재발급 핸들러가 호출되고 새 토큰으로 세션이 갱신된다',
        () async {
      final auth = GoogleAuthService();
      final refresher = _FakeTokenRefresher(GoogleTokenRefreshResult(
        accessToken: 'token-fresh-123',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ));
      auth.tokenRefreshHandler = refresher.call;

      await GoogleSessionStorage.saveSession(_session(
        token: 'token-expired',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      ));

      final client = await auth.getAuthenticatedClient();

      // 재발급 성공 → 새 토큰을 담은 인증 클라이언트 반환
      expect(client, isNotNull);
      // 재발급 핸들러는 클라이언트 ID·스코프·로그인 힌트와 함께 정확히 1회 호출
      expect(refresher.calls, hasLength(1));
      expect(
        refresher.calls.single.clientId,
        contains('apps.googleusercontent.com'),
      );
      expect(
        refresher.calls.single.scopes,
        contains('https://www.googleapis.com/auth/drive.appdata'),
      );
      expect(refresher.calls.single.loginHint, 'user@example.com');

      // 세션이 새 토큰 + 미래 만료 시각으로 갱신됨 → 이후 동기화는 유효 토큰 사용
      final saved = await GoogleSessionStorage.loadSession();
      expect(saved?.accessToken, 'token-fresh-123');
      expect(saved!.expiresAt!.isAfter(DateTime.now()), isTrue);
    });

    test('만료 임박(5분 안전 마진 내) 토큰도 재발급 대상이다', () async {
      final auth = GoogleAuthService();
      final refresher = _FakeTokenRefresher(GoogleTokenRefreshResult(
        accessToken: 'token-fresh-456',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ));
      auth.tokenRefreshHandler = refresher.call;

      await GoogleSessionStorage.saveSession(_session(
        token: 'token-almost-expired',
        // 5분 마진보다 짧게 남은 토큰은 만료로 간주
        expiresAt: DateTime.now().add(const Duration(minutes: 3)),
      ));

      final client = await auth.getAuthenticatedClient();

      expect(client, isNotNull);
      expect(refresher.calls, hasLength(1));
      final saved = await GoogleSessionStorage.loadSession();
      expect(saved?.accessToken, 'token-fresh-456');
    });

    test('유효한 토큰은 재발급 없이 그대로 사용된다', () async {
      final auth = GoogleAuthService();
      final refresher = _FakeTokenRefresher(GoogleTokenRefreshResult(
        accessToken: 'unused-token',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ));
      auth.tokenRefreshHandler = refresher.call;

      await GoogleSessionStorage.saveSession(_session(
        token: 'token-valid',
        expiresAt: DateTime.now().add(const Duration(minutes: 30)),
      ));

      final client = await auth.getAuthenticatedClient();

      expect(client, isNotNull);
      // 재발급이 불필요하므로 핸들러가 호출되지 않아야 한다
      expect(refresher.calls, isEmpty);
      final saved = await GoogleSessionStorage.loadSession();
      expect(saved?.accessToken, 'token-valid');
    });

    test('무효 토큰(\'null\'·빈 문자열 등)도 재발급 대상이다', () async {
      final auth = GoogleAuthService();
      final refresher = _FakeTokenRefresher(GoogleTokenRefreshResult(
        accessToken: 'token-fresh-789',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ));
      auth.tokenRefreshHandler = refresher.call;

      for (final badToken in ['null', '']) {
        await GoogleSessionStorage.saveSession(_session(
          token: badToken,
          expiresAt: DateTime.now().add(const Duration(minutes: 30)),
        ));

        final client = await auth.getAuthenticatedClient();

        expect(client, isNotNull, reason: 'token: $badToken');
        expect(refresher.calls, hasLength(1), reason: 'token: $badToken');
        final saved = await GoogleSessionStorage.loadSession();
        expect(saved?.accessToken, 'token-fresh-789', reason: 'token: $badToken');
        refresher.calls.clear();
      }
    });

    test('만료 시각이 없는 레거시 세션도 재발급 대상이다', () async {
      final auth = GoogleAuthService();
      final refresher = _FakeTokenRefresher(GoogleTokenRefreshResult(
        accessToken: 'token-fresh-legacy',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ));
      auth.tokenRefreshHandler = refresher.call;

      await GoogleSessionStorage.saveSession(_session(
        token: 'token-no-expiry',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ));
      // 레거시 세션: expiresAt 없이 저장
      final session = await GoogleSessionStorage.loadSession();
      await GoogleSessionStorage.saveSession(GoogleSessionData(
        id: session!.id,
        email: session.email,
        displayName: session.displayName,
        photoUrl: session.photoUrl,
        accessToken: session.accessToken,
        expiresAt: null,
      ));

      final client = await auth.getAuthenticatedClient();

      expect(client, isNotNull);
      expect(refresher.calls, hasLength(1));
      final saved = await GoogleSessionStorage.loadSession();
      expect(saved?.accessToken, 'token-fresh-legacy');
    });

    test('재발급 실패 시 null을 반환하고 예외를 던지지 않는다', () async {
      final auth = GoogleAuthService();
      final refresher = _FakeTokenRefresher(null);
      auth.tokenRefreshHandler = refresher.call;

      await GoogleSessionStorage.saveSession(_session(
        token: 'token-expired',
        expiresAt: DateTime.now().subtract(const Duration(hours: 2)),
      ));

      final client = await auth.getAuthenticatedClient();

      expect(client, isNull);
      expect(refresher.calls, hasLength(1));
    });
  });

  group('GoogleAuthService.reauthenticate — 401 후 재인증', () {
    test('만료 세션으로 재발급을 시도해 새 인증 클라이언트를 만든다', () async {
      final auth = GoogleAuthService();
      final refresher = _FakeTokenRefresher(GoogleTokenRefreshResult(
        accessToken: 'token-reauth-000',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ));
      auth.tokenRefreshHandler = refresher.call;

      await GoogleSessionStorage.saveSession(_session(
        token: 'token-expired',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ));

      final client = await auth.reauthenticate();

      expect(client, isNotNull);
      expect(refresher.calls, hasLength(1));
      final saved = await GoogleSessionStorage.loadSession();
      expect(saved?.accessToken, 'token-reauth-000');
    });
  });

  group('GoogleAuthService — interactive 팝업 재인증 & 리다이렉트 복귀', () {
    test('수동 동기화(interactive)는 핸들러에 interactive=true로 전달된다', () async {
      final auth = GoogleAuthService();
      final refresher = _FakeTokenRefresher(GoogleTokenRefreshResult(
        accessToken: 'token-interactive-1',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ));
      auth.tokenRefreshHandler = refresher.call;

      await GoogleSessionStorage.saveSession(_session(
        token: 'token-expired',
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      ));

      // 사용자 제스처(동기화 버튼) 경로 — interactive 팝업 재인증 허용
      final client = await auth.getAuthenticatedClient(interactive: true);

      expect(client, isNotNull);
      expect(refresher.calls.single.interactive, isTrue);
      final saved = await GoogleSessionStorage.loadSession();
      expect(saved?.accessToken, 'token-interactive-1');
    });

    test('자동 동기화(비interactive)는 핸들러에 interactive=false로 전달된다', () async {
      final auth = GoogleAuthService();
      final refresher = _FakeTokenRefresher(GoogleTokenRefreshResult(
        accessToken: 'token-silent-1',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ));
      auth.tokenRefreshHandler = refresher.call;

      await GoogleSessionStorage.saveSession(_session(
        token: 'token-expired',
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      ));

      final client = await auth.getAuthenticatedClient();

      expect(client, isNotNull);
      expect(refresher.calls.single.interactive, isFalse);
    });

    test('리다이렉트 복귀 토큰(persistAccessToken)이 저장 세션에 반영된다', () async {
      final auth = GoogleAuthService();

      await GoogleSessionStorage.saveSession(_session(
        token: 'token-old',
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      ));

      final newExpiry = DateTime.now().add(const Duration(hours: 1));
      await auth.persistAccessToken('token-redirect-1', newExpiry);

      final saved = await GoogleSessionStorage.loadSession();
      expect(saved?.accessToken, 'token-redirect-1');
      // 유저 정보(id/email)는 그대로 유지 — 연결 상태가 끊기지 않는다.
      expect(saved?.email, 'user@example.com');
      expect(saved?.expiresAt?.millisecondsSinceEpoch, newExpiry.millisecondsSinceEpoch);
    });
  });
}
