import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguistic_cabinet/features/words/presentation/screens/word_form_screen.dart';
import 'package:linguistic_cabinet/features/words/presentation/screens/word_list_screen.dart';
import 'package:linguistic_cabinet/shared/services/tts_service.dart';
import 'helpers.dart';
import 'word_detail_modal_test.dart';

class FakeTestTtsService extends TtsService {
  final List<String> spoken = [];

  @override
  Future<void> speak(String text, {TtsVoiceGender gender = TtsVoiceGender.female}) async {
    spoken.add('$text:${gender.name}');
  }

  @override
  Future<void> stop() async {}
}

void main() {
  testWidgets('WordFormScreen 단어 입력 시 여성/남성 발음 듣기 버튼 표시 및 탭 동작', (tester) async {
    ignoreTestFontOverflow();
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final fakeRepo = FakeWordRepository([]);
    final fakeTts = FakeTestTtsService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wordRepositoryProvider.overrideWithValue(fakeRepo),
          ttsServiceProvider.overrideWithValue(fakeTts),
        ],
        child: const MaterialApp(
          home: WordFormScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 발음 듣기 섹션 확인
    expect(find.text('PRONUNCIATION · 발음 듣기:'), findsOneWidget);
    expect(find.text('♀ 여성'), findsOneWidget);
    expect(find.text('♂ 남성'), findsOneWidget);

    // 단어 입력
    final englishField = find.byType(TextFormField).first;
    await tester.enterText(englishField, 'horizon');
    await tester.pumpAndSettle();

    // 여성 발음 버튼 탭
    await tester.tap(find.text('♀ 여성'));
    await tester.pumpAndSettle();

    expect(fakeTts.spoken, contains('horizon:female'));

    // 남성 발음 버튼 탭
    await tester.tap(find.text('♂ 남성'));
    await tester.pumpAndSettle();

    expect(fakeTts.spoken, contains('horizon:male'));
  });
}
