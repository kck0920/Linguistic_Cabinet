import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:linguistic_cabinet/shared/services/google_auth_service.dart';
import 'package:linguistic_cabinet/shared/services/google_session_storage.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.path);
  final String path;

  @override
  Future<String?> getApplicationSupportPath() async => path;
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
    await GoogleSessionStorage.clearSession();
  });

  tearDown(() {
    final auth = GoogleAuthService();
    auth.forceWebAuthPath = false;
  });

  group('GoogleAuthService 세션 및 만료 제어', () {
    test('유효한 토큰이 있는 세션은 getAuthenticatedClient에서 바로 반환된다', () async {
      final auth = GoogleAuthService();
      final validSession = _session(
        token: 'token-valid',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      await GoogleSessionStorage.saveSession(validSession);

      final client = await auth.getAuthenticatedClient();
      expect(client, isNotNull);
    });

    test('forceExpireAccessToken 호출 시 세션이 만료 상태로 전환된다', () async {
      final auth = GoogleAuthService();
      final sessionObj = _session(
        token: 'token-test',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      await GoogleSessionStorage.saveSession(sessionObj);

      await auth.forceExpireAccessToken();

      final reloaded = await GoogleSessionStorage.loadSession();
      expect(reloaded, isNotNull);
      expect(reloaded!.expiresAt!.isBefore(DateTime.now()), isTrue);
    });
  });
}
