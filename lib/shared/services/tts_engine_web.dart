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

  web.HTMLAudioElement? _currentAudio;
  Timer? _audioTimeoutTimer;

  @override
  Future<void> init() async {
    try {
      final synth = web.window.speechSynthesis;
      synth.onvoiceschanged = ((web.Event e) {
        final voices = synth.getVoices().toDart;
        if (voices.isNotEmpty) {
          _resolveVoices(voices);
        }
      }).toJS;
    } catch (_) {}
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
    if (_voicesLoaded && _cachedMaleVoice != null && _cachedFemaleVoice != null) {
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

    if (rawVoices.isNotEmpty) {
      _resolveVoices(rawVoices);
    }
  }

  void _resolveVoices(List<web.SpeechSynthesisVoice> rawVoices) {
    if (rawVoices.isEmpty) return;

    final candidates = rawVoices
        .map((v) => TtsVoiceCandidate(name: v.name, localeOrLang: v.lang))
        .toList();
    final resolved = TtsVoiceResolver.resolve(candidates);

    _cachedMaleVoice =
        resolved.maleIndex != null ? rawVoices[resolved.maleIndex!] : null;
    _cachedFemaleVoice =
        resolved.femaleIndex != null ? rawVoices[resolved.femaleIndex!] : null;
    _voicesLoaded = true;

    debugPrint('TTS Web Resolved Voices: Male=${_cachedMaleVoice?.name} (${_cachedMaleVoice?.lang}), Female=${_cachedFemaleVoice?.name} (${_cachedFemaleVoice?.lang})');
  }

  /// 브라우저 내장 Web Speech API 재생
  Future<void> _speakViaWebSpeech(String clean, TtsVoiceGender gender) async {
    try {
      final synth = web.window.speechSynthesis;
      if (!_voicesLoaded) {
        await _ensureVoicesLoaded();
      }

      synth.cancel();

      final utterance = web.SpeechSynthesisUtterance(clean);
      final targetVoice = (gender == TtsVoiceGender.male)
          ? _cachedMaleVoice
          : _cachedFemaleVoice;

      if (targetVoice != null) {
        utterance.voice = targetVoice;
        utterance.lang = targetVoice.lang;
        // 전용 성별 보이스를 찾았을 때는 원음 피치(1.0) 사용
        utterance.pitch = 1.0;
      } else {
        utterance.lang = 'en-US';
        // 남성 보이스를 찾지 못해 기본(보통 여성) 음성으로 재생될 경우 저음 피치로 구분
        utterance.pitch = (gender == TtsVoiceGender.male) ? 0.78 : 1.0;
      }

      utterance.rate = 0.97;
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
  Future<void> speak(String text, TtsVoiceGender gender) async {
    final clean = text.trim();
    if (clean.isEmpty) return;

    // 외부 비공식 TTS 스트림의 401 차단 및 비동기 대기 중 user-gesture 만료로 인한
    // 무음 현상을 방지하기 위해 브라우저 내장 Web Speech API를 즉시 호출한다.
    await _speakViaWebSpeech(clean, gender);
  }

  void _stopCurrentAudio() {
    _audioTimeoutTimer?.cancel();
    _audioTimeoutTimer = null;
    if (_currentAudio != null) {
      try {
        _currentAudio?.pause();
        _currentAudio?.currentTime = 0;
        _currentAudio?.removeAttribute('src');
        _currentAudio?.load();
      } catch (_) {}
      _currentAudio = null;
    }
  }

  void _stopAll({bool notify = true}) {
    _stopCurrentAudio();
    try {
      final synth = web.window.speechSynthesis;
      synth.cancel();
    } catch (_) {}
    if (notify) {
      _onComplete?.call();
    }
  }

  @override
  Future<void> stop() async {
    _stopAll(notify: true);
  }
}

BaseTtsEngine createTtsEngine() => TtsEngineWeb();
