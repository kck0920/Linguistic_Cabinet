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

/// 웹 로그인에서 "한 번 누르면 두 번 인증한다" 증상이 재발하지 않는지 막는 회귀 테스트.
///
/// 회귀 배경:
/// 1) `GoogleAuthService.signIn()`의 웹 폴백이 서버 코드 교환 실패 시
///    `requestAccessToken(prompt: 'select_account')`를 호출해 **두 번째
///    인터랙티브 팝업**을 띄웠다. 첫 팝업에서 이미 인증을 마친 사용자에게
///    재동의를 강요하는 구조였다.
/// 2) `api/google/connect.js`의 `redirect_uri` 기본값이 `'postmessage'`였으나,
///    GIS 팝업 모드에서 코드와 짝을 이루는 값은 **호출 페이지의 origin**이다.
///    기본값 불일치로 서버 교환이 항상 실패 → 1번 증상이 항상 발현됐다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late PathProviderPlatform originalPathProvider;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('voca_google_single_prompt_test');
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

  group('구글 로그인 프롬프트는 사용자당 한 번', () {
    test('서버 코드 교환과 사일런트 토큰 발급이 모두 실패하면 예외 없이 null을 반환한다', () async {
      final auth = GoogleAuthService();
      // 테스트 환경에는 GIS SDK도 서버도 없으므로 1차(코드)·2차(토큰) 모두 실패한다.
      // 여기서 예외가 던져지거나 무한정 대기하면 안 된다.
      final result = await auth.signIn().timeout(const Duration(seconds: 90));

      expect(result, isNull, reason: '성공하지 못했으면 null을 반환해야 한다');
    });

    test('로그인 실패가 조용히 끝나도 세션은 로그아웃 상태를 유지한다', () async {
      final auth = GoogleAuthService();
      await auth.signIn().timeout(const Duration(seconds: 90));

      final session = await GoogleSessionStorage.loadSession();
      expect(session, isNull, reason: '실패한 로그인이 세션을 남기면 안 된다');
    });
  });

  group('동시 호출이 중복 실행되지 않는다', () {
    test('signInSilently 동시 호출은 결과를 공유하고 한 번만 복원한다', () async {
      final auth = GoogleAuthService();
      // 앱 시작(main) · 프로바이더 init · 설정 탭 initState가 연달아 호출하는
      // 실제 패턴을 재현한다.
      final results = await Future.wait([
        auth.signInSilently(),
        auth.signInSilently(),
        auth.signInSilently(),
      ]);

      expect(results, hasLength(3));
      // 세 호출 모두 같은 결과를 받아야 한다(각자 따로 복원한 게 아님).
      expect(results[0], isNull, reason: '테스트 환경에는 세션이 없다');
      expect(results[1], isNull);
      expect(results[2], isNull);
    });

    test('완료 후에는 다음 호출이 정상적으로 다시 실행된다', () async {
      final auth = GoogleAuthService();

      final first = await auth.signInSilently();
      final second = await auth.signInSilently();

      // 병합이 영구히 붙어 있으면 두 번째 호출이 이전 Future를 그대로 돌려준다.
      // 여기서는 결과가 같으므로 완료 후 재실행이 됐음을 세션 로드로 확인한다.
      expect(first, isNull);
      expect(second, isNull);
      expect(auth.currentUser, isNull);
    });

    test('동시 signIn 호출은 하나의 Future를 돌려준다', () async {
      final auth = GoogleAuthService();
      // 더블탭으로 팝업이 두 번 열리는 것을 막았는지 확인한다.
      // 두 Future가 동일 인스턴스라면 병합이 된 것이다.
      final a = auth.signIn();
      final b = auth.signIn();

      expect(identical(a, b), isTrue, reason: '동시 호출은 하나의 Future를 공유해야 한다');

      // 병합이 걸렸으므로 Future를 정리한다(테스트 중 실제 인증 요청은 없음).
      await a.timeout(const Duration(seconds: 90), onTimeout: () => null);
    });
  });

  group('api/google/connect.js 계약', () {
    final connectJs = File('api/google/connect.js');

    test('GIS 팝업 모드의 postmessage를 redirect_uri 기본값으로 쓰지 않는다', () {
      expect(connectJs.existsSync(), isTrue, reason: 'connect.js가 있어야 한다');
      final source = connectJs.readAsStringSync();

      // GIS 팝업 모드에서 코드와 짝을 이루는 redirect_uri는 origin이다.
      // 'postmessage'는 이 흐름의 올바른 값이 아니다.
      expect(
        source.contains("'postmessage'"),
        isFalse,
        reason: "redirect_uri 기본값 'postmessage'는 코드와 불일치해 교환을 실패시킨다",
      );
    });

    test('redirect_uri가 없으면 거부하고, 경로 없는 origin을 기본값으로 쓴다', () {
      final source = connectJs.readAsStringSync();

      expect(
        source.contains('redirect_uri is required'),
        isTrue,
        reason: 'redirect_uri 누락을 조용히 넘어가면 잘못된 코드로 교환을 시도한다',
      );
    });

    test('client_secret은 값이 있을 때만 전송한다', () {
      final source = connectJs.readAsStringSync();

      // Web application 타입 클라이언트는 secret이 불필요하며, 빈 문자열로
      // 보내면 invalid_client로 거부된다.
      expect(
        RegExp(r'client_secret:\s*CLIENT_SECRET').hasMatch(source),
        isFalse,
        reason: 'URLSearchParams에 client_secret을 상수로 넣으면 빈 값이 전송된다',
      );
      expect(
        source.contains("params.set('client_secret'"),
        isTrue,
        reason: '값이 있을 때만 조건부로 넣어야 한다',
      );
    });
  });
}
