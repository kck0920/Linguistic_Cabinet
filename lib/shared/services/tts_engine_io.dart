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

      final englishVoices = list.where((v) {
        final loc = (v['locale'] ?? v['lang'] ?? '').toLowerCase();
        return loc.startsWith('en');
      }).toList();

      final pool = englishVoices.isNotEmpty ? englishVoices : list;

      const maleKeywords = [
        'david', 'daniel', 'alex', 'fred', 'eddy', 'reed', 'rocko', 'ralph',
        'albert', 'grandpa', 'mark', 'george', 'guy', 'oliver', 'male',
        'standard-b', 'standard-d', 'wavenet-b', 'wavenet-d', 'neural2-d',
      ];

      const femaleKeywords = [
        'samantha', 'victoria', 'karen', 'zira', 'jenny', 'aria', 'flo',
        'shelley', 'sandy', 'grandma', 'kathy', 'female',
        'standard-a', 'standard-c', 'standard-e', 'wavenet-a', 'wavenet-c', 'neural2-c',
      ];

      Map<String, String>? foundMale;
      for (final kw in maleKeywords) {
        for (final v in pool) {
          final name = (v['name'] ?? '').toLowerCase();
          final g = (v['gender'] ?? '').toLowerCase();
          if (g == 'male' || name.contains(kw)) {
            foundMale = v;
            break;
          }
        }
        if (foundMale != null) break;
      }

      Map<String, String>? foundFemale;
      for (final kw in femaleKeywords) {
        for (final v in pool) {
          final name = (v['name'] ?? '').toLowerCase();
          final g = (v['gender'] ?? '').toLowerCase();
          if (g == 'female' || name.contains(kw)) {
            foundFemale = v;
            break;
          }
        }
        if (foundFemale != null) break;
      }

      _cachedMaleVoice = foundMale;
      _cachedFemaleVoice = foundFemale;
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

      await _tts.setPitch(gender.defaultPitch);
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
