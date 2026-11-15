import 'package:flutter_test/flutter_test.dart';
import 'package:linguistic_cabinet/shared/services/tts_engine_base.dart';
import 'package:linguistic_cabinet/shared/services/tts_service.dart';

void main() {
  group('TtsVoiceResolver', () {
    test('Chrome 웹 음성 목록에서 남성/여성 보이스를 정확히 분리한다', () {
      const voices = [
        TtsVoiceCandidate(name: 'Google US English', localeOrLang: 'en-US'),
        TtsVoiceCandidate(name: 'Google UK English Female', localeOrLang: 'en-GB'),
        TtsVoiceCandidate(name: 'Google UK English Male', localeOrLang: 'en-GB'),
      ];

      final res = TtsVoiceResolver.resolve(voices);
      expect(res.maleIndex, 2);
      expect(res.femaleIndex, 0);
      expect(res.maleIndex, isNot(res.femaleIndex));
    });

    test('female 문자열이 포함된 음성은 male 키워드에 오매칭되지 않는다', () {
      const voices = [
        TtsVoiceCandidate(name: 'Google UK English Female', localeOrLang: 'en-GB'),
        TtsVoiceCandidate(name: 'Custom English Voice', localeOrLang: 'en-US'),
      ];

      final res = TtsVoiceResolver.resolve(voices);
      expect(res.femaleIndex, 0);
      expect(res.maleIndex, 1);
    });

    test('macOS 음성 목록에서 남성(Daniel/Alex/Aaron)과 여성(Samantha)을 분리한다', () {
      const voices = [
        TtsVoiceCandidate(name: 'Fred', localeOrLang: 'en-US'), // 블랙리스트
        TtsVoiceCandidate(name: 'Samantha', localeOrLang: 'en-US'),
        TtsVoiceCandidate(name: 'Aaron', localeOrLang: 'en-US'),
      ];

      final res = TtsVoiceResolver.resolve(voices);
      expect(res.femaleIndex, 1);
      expect(res.maleIndex, 2);
    });

    test('Android Google TTS 코드명에서 남성/여성 보이스를 분리한다', () {
      const voices = [
        TtsVoiceCandidate(name: 'en-us-x-sfg-local', localeOrLang: 'en-US'),
        TtsVoiceCandidate(name: 'en-us-x-iom-local', localeOrLang: 'en-US'),
      ];

      final res = TtsVoiceResolver.resolve(voices);
      expect(res.femaleIndex, 0);
      expect(res.maleIndex, 1);
    });

    test('여성 음성만 있는 환경에서는 남성 보이스로 여성 음성을 덮어쓰지 않는다', () {
      const voices = [
        TtsVoiceCandidate(name: 'Samantha', localeOrLang: 'en-US'),
        TtsVoiceCandidate(name: 'Google US English', localeOrLang: 'en-US'),
      ];

      final res = TtsVoiceResolver.resolve(voices);
      expect(res.femaleIndex, 1);
      expect(res.maleIndex, isNull);
    });

    test('영국식과 미국식 자연스러운 음성이 함께 있으면 미국식(en-US) 음성을 우선 선택한다', () {
      const voices = [
        TtsVoiceCandidate(name: 'Google UK English Male', localeOrLang: 'en-GB'),
        TtsVoiceCandidate(name: 'Microsoft Andrew Online (Natural)', localeOrLang: 'en-US'),
        TtsVoiceCandidate(name: 'Google UK English Female', localeOrLang: 'en-GB'),
        TtsVoiceCandidate(name: 'Microsoft Ava Online (Natural)', localeOrLang: 'en-US'),
      ];

      final res = TtsVoiceResolver.resolve(voices);
      expect(res.maleIndex, 1);
      expect(res.femaleIndex, 3);
    });

    test('Eloquence 기계음(Eddy, Reed 등)을 차단하고 자연스러운 음성을 선택한다', () {
      const voices = [
        TtsVoiceCandidate(name: 'Eddy (English (US))', localeOrLang: 'en-US'),
        TtsVoiceCandidate(name: 'Reed (English (US))', localeOrLang: 'en-US'),
        TtsVoiceCandidate(name: 'Aaron', localeOrLang: 'en-US'),
        TtsVoiceCandidate(name: 'Samantha (Enhanced)', localeOrLang: 'en-US'),
      ];

      final res = TtsVoiceResolver.resolve(voices);
      expect(res.maleIndex, 2);
      expect(res.femaleIndex, 3);
    });
  });

  group('splitExampleSentences', () {
    test('줄바꿈과 마침표로 구분된 여러 예문을 한 문장씩 정확히 분리한다', () {
      const raw = '''We have our annual performance evals coming up next week.
The team is running evals on the new AI model before launching it.
Students have to fill out course evals at the end of every semester.''';

      final sentences = splitExampleSentences(raw);
      expect(sentences, [
        'We have our annual performance evals coming up next week.',
        'The team is running evals on the new AI model before launching it.',
        'Students have to fill out course evals at the end of every semester.',
      ]);
    });

    test('한 줄에 여러 문장이 있어도 문장 경계에서 분리한다', () {
      const raw = 'First sentence here. Second sentence? Third one!';
      final sentences = splitExampleSentences(raw);
      expect(sentences, [
        'First sentence here.',
        'Second sentence?',
        'Third one!',
      ]);
    });
  });
}
