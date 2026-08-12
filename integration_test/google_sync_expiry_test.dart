import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:web/web.dart' as web;

import 'package:linguistic_cabinet/main.dart' as app;
import 'package:linguistic_cabinet/shared/services/google_auth_service.dart';

/// 웹 통합 테스트 — '구글 연결 후 1시간이 지나 access token이 만료된 뒤
/// 동기화 버튼을 눌렀을 때'의 실제 브라우저(Chrome) 동작을 검증한다.
///
/// - 앱 부팅 전 localStorage에 만료된 구글 세션을 심어, 저장 세션 기반
///   '연동됨' 상태가 복원되는지 확인한다.
/// - '지금 동기화' 클릭 시 토큰 재발급(GIS Token Client) 경로가 실행되고,
///   실 구글 세션이 없어 재발급이 실패해도 예외 없이 우아하게
///   '동기화 실패' SnackBar가 뜨는지 확인한다.
/// - 이어서 localStorage를 만료되지 않은 세션(가짜 토큰)으로 교체해,
///   Drive API 401 → 재인증 시도 → 우아한 실패 흐름도 함께 확인한다.
///
/// 실행: flutter test integration_test/google_sync_expiry_test.dart -d chrome
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('만료 토큰 동기화 → 재발급 시도 → 예외 없이 우아한 실패 (실 브라우저)',
      (tester) async {
    // 테스트 중 앱에서 발생한 예외를 수집해 마지막에 진단 출력 (오버플로우 제외 검증)
    final capturedErrors = <FlutterErrorDetails>[];
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      capturedErrors.add(details);
      originalOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalOnError);

    // ── 앱 부팅 전: 만료된 구글 세션 시드 (expiresAt = 과거)
    web.window.localStorage.setItem(
      'voca_google_session_v1',
      jsonEncode(<String, Object?>{
        'id': 'test-user-1',
        'email': 'expiry.test.user@gmail.com',
        'displayName': 'Expiry Test',
        'photoUrl': null,
        'accessToken': 'fake-expired-token-abc',
        'refreshToken': null,
        'expiresAt': 1700000000000,
      }),
    );

    // 자동화 브라우저에는 실 구글 세션이 없어 재인증 팝업이 열리지 않도록
    // 팝업/리다이렉트 재인증을 끈다 (우아한 실패 경로 검증에 집중).
    GoogleAuthService.suppressInteractiveReauth = true;
    app.main();

    // 앱 부팅 완료 대기 — 웹에서는 GIS 스크립트 로드·DB 초기화 때문에
    // runApp(첫 프레임)이 수 초 늦어질 수 있어, 내비가 나타날 때까지 폴링한다.
    await _waitForBoot(tester);

    // ── 설정 탭 진입 (넓은 화면: 상단 내비 탭 / 좁은 화면: 하단 네비)
    final wideSettingsTab = find.text('06 SETTINGS');
    if (wideSettingsTab.evaluate().isNotEmpty) {
      await tester.tap(wideSettingsTab);
    } else {
      await tester.tap(find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text('설정'),
      ));
    }
    await tester.pumpAndSettle();
    await tester.tap(find.text('DATA & BACKUP'));
    await tester.pumpAndSettle();

    // 저장된 세션 기반 '연동됨' 상태 복원 확인
    expect(find.text('GOOGLE 계정과 연동됨'), findsOneWidget);
    expect(find.text('expiry.test.user@gmail.com'), findsOneWidget);

    // ── [시나리오 1] 만료 토큰 → 재발급 시도 → 우아한 실패
    await tester.ensureVisible(find.text('지금 동기화'));
    await tester.tap(find.text('지금 동기화'));
    // 탭이 실제로 동기화를 시작했는지 확인 (버튼이 '동기화 중...'으로 전환)
    await _waitForText(tester, '동기화 중');
    // 성공/실패 SnackBar 중 하나가 떠야 한다
    await _waitForText(tester, 'Google Drive 동기화');
    final resultSnack = find.textContaining('Google Drive 동기화');
    final resultText =
        (tester.widget<Text>(resultSnack.first)).data ?? '';
    expect(resultText, contains('실패'),
        reason: '실 구글 세션이 없으므로 실패 SnackBar가 예상됨. 실제: $resultText');

    // 첫 SnackBar가 사라질 때까지 대기 (다음 시나리오와 겹치지 않도록)
    await _waitForTextGone(tester, 'Google Drive 동기화');

    // ── [시나리오 2] 만료되지 않은 세션 + 가짜 토큰 → Drive 401 → 재인증 시도
    web.window.localStorage.setItem(
      'voca_google_session_v1',
      jsonEncode(<String, Object?>{
        'id': 'test-user-1',
        'email': 'expiry.test.user@gmail.com',
        'displayName': 'Expiry Test',
        'photoUrl': null,
        'accessToken': 'fake-valid-token-xyz',
        'refreshToken': null,
        'expiresAt':
            DateTime.now().millisecondsSinceEpoch + 3600000, // 아직 유효
      }),
    );

    await tester.tap(find.text('지금 동기화'));
    await _waitForText(tester, 'Google Drive 동기화');
    final resultSnack2 = find.textContaining('Google Drive 동기화');
    final resultText2 =
        (tester.widget<Text>(resultSnack2.first)).data ?? '';
    expect(resultText2, contains('실패'),
        reason: '가짜 토큰 401 → 재인증 실패 시 실패 SnackBar 예상. 실제: $resultText2');

    // ── 예외 검증
    // 프레임워크에 기록된 예외를 소진해 'Multiple exceptions' 종료 실패를 방지한다.
    while (tester.takeException() != null) {}
    // 알려진 테스트 환경/기존 UI 진단은 허용하고, 그 외 실제 오류가 있으면
    // 상세 메시지와 함께 실패시킨다.
    //  - RenderFlex overflow: 좁은 뷰포트의 테스트 환경 아티팩트
    //  - ListTile ink 경고: 설정 화면 구글 드라이브 섹션의 기존 DecoratedBox 패턴
    //    (토큰 수정과 무관한 사전 존재 경고)
    final unexpected = capturedErrors.where((d) {
      final msg = d.exceptionAsString();
      if (msg.contains('overflowed')) return false;
      if (msg.contains('ListTile background color or ink splashes')) return false;
      return true;
    }).toList();
    expect(unexpected, isEmpty,
        reason: '예상치 못한 예외 ${unexpected.length}건:\n'
            '${unexpected.map((d) => d.exceptionAsString()).join('\n---\n')}');
  });
}

/// 앱 첫 프레임(내비)이 나타날 때까지 폴링한다.
Future<void> _waitForBoot(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 40),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump();
    final navVisible =
        find.text('06 SETTINGS').evaluate().isNotEmpty ||
        find.byType(BottomNavigationBar).evaluate().isNotEmpty;
    if (navVisible) return;
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  fail('$timeout 안에 앱이 부팅되지 않았습니다.');
}

/// 실제 비동기(네트워크·GIS 재발급)가 진행되는 동안 [text]가 나타날 때까지
/// 실시간으로 폴링한다. (통합 테스트는 실시간 바인딩 — pumpAndSettle 대신 사용)
Future<void> _waitForText(
  WidgetTester tester,
  String text, {
  Duration timeout = const Duration(seconds: 50),
}) async {
  final finder = find.textContaining(text);
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump();
    if (finder.evaluate().isNotEmpty) return;
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  fail('$timeout 안에 "$text"가 나타나지 않았습니다.\n'
      '현재 화면 텍스트: ${_onScreenTexts(tester)}');
}

/// 화면에 보이는 모든 Text 위젯의 내용을 수집한다 (진단용).
List<String?> _onScreenTexts(WidgetTester tester) {
  return tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data)
      .toList();
}

/// [text]가 화면에서 사라질 때까지 폴링한다.
Future<void> _waitForTextGone(
  WidgetTester tester,
  String text, {
  Duration timeout = const Duration(seconds: 12),
}) async {
  final finder = find.textContaining(text);
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump();
    if (finder.evaluate().isEmpty) return;
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  fail('$timeout 안에 "$text"가 사라지지 않았습니다.');
}
