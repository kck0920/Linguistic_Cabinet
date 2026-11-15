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

  /// 고품질 원어민 오디오 스트림 URL 목록 (1순위: Polly 서버리스 스트림, 2순위: Google/Youdao 원음 스트림)
  List<String> _getAudioStreamUrls(String text, TtsVoiceGender gender) {
    final clean = text.trim();
    if (clean.isEmpty) return const [];

    final encoded = Uri.encodeComponent(clean);
    final urls = <String>[];

    // 1순위: Vercel Serverless Function을 통한 Amazon Polly 최고급 원어민 네이티브 음성 (남성: Matthew, 여성: Joanna)
    // (현재 외부 프록시가 차단된 경우 빠른 폴백 후 Web Speech API 사용)
    urls.add('/api/tts?text=$encoded&gender=${gender.name}');

    // 2순위 (오프라인 / 로컬 개발 환경 폴백):
    // 참고: Youdao dictvoice는 여성 성우 음성만 제공하므로 남성 발음에는 사용하지 않음
    if (gender == TtsVoiceGender.female) {
      urls.add('https://translate.google.com/translate_tts?ie=UTF-8&tl=en-US&client=tw-ob&q=$encoded');
    }

    return urls;
  }

  /// 원어민 오디오 스트림 재생 시도 (순차적 폴백)
  Future<bool> _tryPlayAudioStream(String text, TtsVoiceGender gender) async {
    final urls = _getAudioStreamUrls(text, gender);
    if (urls.isEmpty) return false;

    for (final url in urls) {
      final success = await _playSingleAudioUrl(url);
      if (success) {
        return true;
      }
    }
    return false;
  }

  Future<bool> _playSingleAudioUrl(String url) async {
    _stopAll(notify: false);

    final completer = Completer<bool>();
    try {
      final audio = web.HTMLAudioElement();
      audio.src = url;
      _currentAudio = audio;

      void cleanup() {
        _audioTimeoutTimer?.cancel();
        _audioTimeoutTimer = null;
        if (_currentAudio == audio) {
          _currentAudio = null;
        }
      }

      audio.onplay = ((web.Event e) {
        // 재생이 정상 시작되었으므로 타임아웃 타이머 취소 (긴 문장 완독 보장)
        _audioTimeoutTimer?.cancel();
        _audioTimeoutTimer = null;
        _onStart?.call();
      }).toJS;

      audio.onended = ((web.Event e) {
        cleanup();
        _onComplete?.call();
        if (!completer.isCompleted) completer.complete(true);
      }).toJS;

      audio.onerror = ((web.Event e) {
        cleanup();
        if (!completer.isCompleted) completer.complete(false);
      }).toJS;

      // 4.5초 내에 재생이 시작되지 않으면 다음 소스로 Fallback
      _audioTimeoutTimer = Timer(const Duration(milliseconds: 4500), () {
        if (!completer.isCompleted) {
          cleanup();
          completer.complete(false);
        }
      });

      final playPromise = audio.play();
      playPromise.toDart.catchError((_) {
        cleanup();
        if (!completer.isCompleted) completer.complete(false);
        return null;
      });

      return await completer.future;
    } catch (_) {
      _stopCurrentAudio();
      return false;
    }
  }

  /// 브라우저 내장 Web Speech API Fallback
  Future<void> _speakViaWebSpeech(String clean, TtsVoiceGender gender) async {
    try {
      final synth = web.window.speechSynthesis;
      await _ensureVoicesLoaded();

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

    await _ensureVoicesLoaded();
    final hasDedicatedWebVoice = (gender == TtsVoiceGender.male)
        ? _cachedMaleVoice != null
        : _cachedFemaleVoice != null;

    // 전용 성별 Web Speech 보이스가 준비되어 있으면 즉시 재생 (네트워크 지연 및 여성 폴백 방지)
    if (hasDedicatedWebVoice) {
      await _speakViaWebSpeech(clean, gender);
      return;
    }

    // 전용 Web Speech 보이스가 없을 때만 오디오 스트림 시도 후 Web Speech 폴백
    final audioSuccess = await _tryPlayAudioStream(clean, gender);
    if (audioSuccess) {
      return;
    }

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
