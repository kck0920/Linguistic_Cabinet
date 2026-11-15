import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'tts_engine_base.dart';

class TtsEngineIo implements BaseTtsEngine {
  final FlutterTts _tts = FlutterTts();
  VoidCallback? _onStart;
  VoidCallback? _onComplete;
  void Function(String msg)? _onError;

  Map<String, String>? _cachedMaleVoice;
  Map<String, String>? _cachedFemaleVoice;
  bool _initialized = false;

  @override
  void setHandlers({
    VoidCallback? onStart,
    VoidCallback? onComplete,
    void Function(String msg)? onError,
  }) {
    _onStart = onStart;
    _onComplete = onComplete;
    _onError = onError;
  }

  @override
  Future<void> init() async {
    if (_initialized) return;
    try {
      await _tts.setLanguage("en-US");
      await _tts.setSpeechRate(0.48);
      await _tts.setVolume(1.0);

      _tts.setStartHandler(() => _onStart?.call());
      _tts.setCompletionHandler(() => _onComplete?.call());
      _tts.setCancelHandler(() => _onComplete?.call());
      _tts.setErrorHandler((msg) {
        debugPrint('IO TTS Error: $msg');
        _onError?.call(msg);
        _onComplete?.call();
      });

      await _loadAndResolveVoices();
      _initialized = true;
    } catch (e) {
      debugPrint('IO TTS init warning: $e');
    }
  }

  Future<void> _loadAndResolveVoices() async {
    try {
      final voices = await _tts.getVoices;
      if (voices is! List || voices.isEmpty) return;

      final list = voices
          .whereType<Map>()
          .map((v) => v.map((k, val) => MapEntry(k.toString(), val.toString())))
          .toList();

      final candidates = list
          .map((v) => TtsVoiceCandidate(
                name: v['name'] ?? '',
                localeOrLang: v['locale'] ?? v['lang'] ?? '',
                gender: v['gender'] ?? '',
              ))
          .toList();

      final resolved = TtsVoiceResolver.resolve(candidates);
      _cachedMaleVoice =
          resolved.maleIndex != null ? list[resolved.maleIndex!] : null;
      _cachedFemaleVoice =
          resolved.femaleIndex != null ? list[resolved.femaleIndex!] : null;
    } catch (e) {
      debugPrint('IO TTS resolve voices error: $e');
    }
  }

  @override
  Future<void> speak(String text, TtsVoiceGender gender) async {
    final clean = text.trim();
    if (clean.isEmpty) return;

    try {
      await init();
      if (_cachedMaleVoice == null || _cachedFemaleVoice == null) {
        await _loadAndResolveVoices();
      }

      await _tts.stop();

      final targetVoice = (gender == TtsVoiceGender.male)
          ? _cachedMaleVoice
          : _cachedFemaleVoice;

      if (targetVoice != null && targetVoice['name'] != null) {
        await _tts.setVoice({
          'name': targetVoice['name']!,
          'locale': targetVoice['locale'] ?? targetVoice['lang'] ?? 'en-US',
        });
      }
      // 피치 변조 시 합성 노이즈가 발생하므로 항상 원음(1.0) 적용
      await _tts.setPitch(1.0);
      await _tts.speak(clean);
    } catch (e) {
      debugPrint('IO TTS speak error: $e');
      _onComplete?.call();
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
    _onComplete?.call();
  }
}

BaseTtsEngine createTtsEngine() => TtsEngineIo();
