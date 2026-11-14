import 'package:flutter_test/flutter_test.dart';
import 'package:linguistic_cabinet/shared/services/tts_engine_base.dart';

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
  });
}
