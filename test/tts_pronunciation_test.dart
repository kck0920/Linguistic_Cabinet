import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguistic_cabinet/core/theme/cabinet_colors.dart';
import 'package:linguistic_cabinet/core/theme/cabinet_theme.dart';
import 'package:linguistic_cabinet/features/review/presentation/screens/review_screen.dart';
import 'package:linguistic_cabinet/features/settings/presentation/widgets/settings_algo_tab.dart';
import 'package:linguistic_cabinet/shared/services/tts_service.dart';
import 'helpers.dart';

class FakeTtsService extends TtsService {
  final List<Map<String, dynamic>> speakCalls = [];

  @override
  Future<void> speak(String text, {TtsVoiceGender gender = TtsVoiceGender.female}) async {
    speakCalls.add({
      'text': text,
      'gender': gender,
    });
  }

  @override
  Future<void> stop() async {}
}

void main() {
  test('TtsVoiceGender enum 및 변환 테스트', () {
    expect(TtsVoiceGender.fromString('male'), equals(TtsVoiceGender.male));
    expect(TtsVoiceGender.fromString('female'), equals(TtsVoiceGender.female));
    expect(TtsVoiceGender.fromString(null), equals(TtsVoiceGender.female));
    expect(TtsVoiceGender.fromString('other'), equals(TtsVoiceGender.female));

    expect(TtsVoiceGender.female.symbol, equals('♀'));
    expect(TtsVoiceGender.male.symbol, equals('♂'));
    expect(TtsVoiceGender.female.defaultPitch, greaterThan(1.0));
    expect(TtsVoiceGender.male.defaultPitch, lessThan(1.0));
  });

  testWidgets('CabinetPronounceButtons 여성 및 남성 발음 버튼 렌더링 및 탭 시 speak 호출', (tester) async {
    final fakeTts = FakeTtsService();
    final colors = CabinetColors.fromMode(CabinetThemeMode.sepia);
    final theme = CabinetTheme(colors);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ttsServiceProvider.overrideWithValue(fakeTts),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: CabinetPronounceButtons(
              word: 'serendipity',
              colors: colors,
              theme: theme,
              compact: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 여성, 남성 버튼 확인
    expect(find.text('♀ 여성'), findsOneWidget);
    expect(find.text('♂ 남성'), findsOneWidget);

    // 여성 발음 버튼 탭
    await tester.tap(find.text('♀ 여성'));
    await tester.pumpAndSettle();

    expect(fakeTts.speakCalls.length, equals(1));
    expect(fakeTts.speakCalls.first['text'], equals('serendipity'));
    expect(fakeTts.speakCalls.first['gender'], equals(TtsVoiceGender.female));

    // 남성 발음 버튼 탭
    await tester.tap(find.text('♂ 남성'));
    await tester.pumpAndSettle();

    expect(fakeTts.speakCalls.length, equals(2));
    expect(fakeTts.speakCalls.last['text'], equals('serendipity'));
    expect(fakeTts.speakCalls.last['gender'], equals(TtsVoiceGender.male));
  });

  testWidgets('SettingsAlgoTab 발음 음성 설정 카드 렌더링 및 기본 음성 변경', (tester) async {
    ignoreTestFontOverflow();
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final fakeRepo = FakeStatsRepository();
    final fakeTts = FakeTtsService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reviewRepositoryProvider.overrideWithValue(fakeRepo),
          ttsServiceProvider.overrideWithValue(fakeTts),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SettingsAlgoTab(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 발음 음성 설정 헤더 확인
    expect(find.text('PRONUNCIATION VOICE'), findsOneWidget);
    expect(find.text('발음 음성 성별 설정'), findsOneWidget);
    expect(find.text('여성 (Female)'), findsOneWidget);
    expect(find.text('남성 (Male)'), findsOneWidget);

    // 남성 음성으로 변경 탭
    await tester.ensureVisible(find.text('남성 (Male)'));
    await tester.tap(find.text('남성 (Male)'));
    await tester.pumpAndSettle();

    // 설정 테이블에 저장되었는지 확인
    expect(fakeRepo.settings['tts_voice_gender'], equals('male'));
  });
}
