import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import 'tts_engine_base.dart';

class TtsEngineWeb implements BaseTtsEngine {
  VoidCallback? _onStart;
  VoidCallback? _onComplete;
  void Function(String msg)? _onError;

  web.SpeechSynthesisVoice? _cachedMaleVoice;
  web.SpeechSynthesisVoice? _cachedFemaleVoice;
  bool _voicesLoaded = false;

  @override
  Future<void> init() async {
    await _ensureVoicesLoaded();
  }

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

  Future<void> _ensureVoicesLoaded() async {
    if (_voicesLoaded && (_cachedMaleVoice != null || _cachedFemaleVoice != null)) {
      return;
    }

    final synth = web.window.speechSynthesis;
    var rawVoices = synth.getVoices().toDart;

    // 브라우저 초기 로딩 타이밍 이슈 방지: 비어있으면 최대 1.5초 동안 대기/폴링
    if (rawVoices.isEmpty) {
      for (int i = 0; i < 15; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        rawVoices = synth.getVoices().toDart;
        if (rawVoices.isNotEmpty) break;
      }
    }

    _resolveVoices(rawVoices);
  }

  void _resolveVoices(List<web.SpeechSynthesisVoice> rawVoices) {
    if (rawVoices.isEmpty) return;

    // 1. 영어 음성 필터링 (en-US, en-GB, en-AU 등)
    final englishVoices = rawVoices.where((v) {
      final lang = v.lang.toLowerCase();
      return lang.startsWith('en');
    }).toList();

    final pool = englishVoices.isNotEmpty ? englishVoices : rawVoices;

    // 2. 남성 음성 키워드 (우선순위 순서)
    const maleKeywords = [
      'google uk english male',
      'david',
      'daniel',
      'alex',
      'fred',
      'eddy',
      'reed',
      'rocko',
      'ralph',
      'albert',
      'grandpa',
      'mark',
      'george',
      'guy',
      'oliver',
      'male',
      'standard-b',
      'standard-d',
      'wavenet-b',
      'wavenet-d',
      'neural2-d',
    ];

    // 3. 여성 음성 키워드 (우선순위 순서)
    const femaleKeywords = [
      'google us english',
      'google uk english female',
      'samantha',
      'victoria',
      'karen',
      'zira',
      'jenny',
      'aria',
      'flo',
      'shelley',
      'sandy',
      'grandma',
      'kathy',
      'female',
      'standard-a',
      'standard-c',
      'standard-e',
      'wavenet-a',
      'wavenet-c',
      'neural2-c',
    ];

    // 남성 보이스 탐색
    web.SpeechSynthesisVoice? foundMale;
    for (final kw in maleKeywords) {
      for (final v in pool) {
        if (v.name.toLowerCase().contains(kw)) {
          foundMale = v;
          break;
        }
      }
      if (foundMale != null) break;
    }

    // 여성 보이스 탐색
    web.SpeechSynthesisVoice? foundFemale;
    for (final kw in femaleKeywords) {
      for (final v in pool) {
        if (v.name.toLowerCase().contains(kw)) {
          foundFemale = v;
          break;
        }
      }
      if (foundFemale != null) break;
    }

    // 만약 한쪽만 못 찾은 경우 후보군에서 겹치지 않는 보이스 선택
    if (foundMale == null && pool.isNotEmpty) {
      foundMale = pool.firstWhere(
        (v) => v != foundFemale,
        orElse: () => pool.first,
      );
    }
    if (foundFemale == null && pool.isNotEmpty) {
      foundFemale = pool.firstWhere(
        (v) => v != foundMale,
        orElse: () => pool.last,
      );
    }

    _cachedMaleVoice = foundMale;
    _cachedFemaleVoice = foundFemale;
    _voicesLoaded = true;

    debugPrint('TTS Web Resolved Voices: Male=${_cachedMaleVoice?.name} (${_cachedMaleVoice?.lang}), Female=${_cachedFemaleVoice?.name} (${_cachedFemaleVoice?.lang})');
  }

  @override
  Future<void> speak(String text, TtsVoiceGender gender) async {
    final clean = text.trim();
    if (clean.isEmpty) return;

    try {
      final synth = web.window.speechSynthesis;
      await _ensureVoicesLoaded();

      // 이전 재생 즉시 취소
      synth.cancel();

      final utterance = web.SpeechSynthesisUtterance(clean);
      final targetVoice = (gender == TtsVoiceGender.male)
          ? _cachedMaleVoice
          : _cachedFemaleVoice;

      if (targetVoice != null) {
        utterance.voice = targetVoice;
        utterance.lang = targetVoice.lang;
      } else {
        utterance.lang = 'en-US';
      }

      // 뚜렷한 남/여 톤 구분을 위한 최적화 피치
      utterance.pitch = (gender == TtsVoiceGender.male) ? 0.75 : 1.15;
      utterance.rate = 0.9;
      utterance.volume = 1.0;

      utterance.onstart = ((web.Event e) {
        _onStart?.call();
      }).toJS;

      utterance.onend = ((web.Event e) {
        _onComplete?.call();
      }).toJS;

      utterance.onerror = ((web.SpeechSynthesisErrorEvent e) {
        debugPrint('Web TTS utterance error: ${e.error}');
        _onError?.call(e.error);
        _onComplete?.call();
      }).toJS;

      synth.speak(utterance);
    } catch (e) {
      debugPrint('Web TTS speak error: $e');
      _onError?.call(e.toString());
      _onComplete?.call();
    }
  }

  @override
  Future<void> stop() async {
    try {
      final synth = web.window.speechSynthesis;
      synth.cancel();
    } catch (_) {}
    _onComplete?.call();
  }
}

BaseTtsEngine createTtsEngine() => TtsEngineWeb();
