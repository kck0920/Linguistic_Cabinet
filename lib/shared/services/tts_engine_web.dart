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

    // 1. 기계음/로봇 변조 구형 보이스 블랙리스트 전면 차단
    const robotBlacklist = [
      'fred', 'albert', 'ralph', 'bad news', 'bahh', 'bells', 'boing',
      'bubbles', 'cellos', 'deranged', 'good news', 'hysterical',
      'pipe organ', 'trinoids', 'whisper', 'zarvox', 'junior',
      'princess', 'espeak'
    ];

    final filtered = rawVoices.where((v) {
      final name = v.name.toLowerCase();
      return !robotBlacklist.any((kw) => name.contains(kw));
    }).toList();

    final candidatePool = filtered.isNotEmpty ? filtered : rawVoices;

    // 영어 음성 필터링 (en-US, en-GB, en-AU 등)
    final englishVoices = candidatePool.where((v) {
      final lang = v.lang.toLowerCase();
      return lang.startsWith('en');
    }).toList();

    final pool = englishVoices.isNotEmpty ? englishVoices : candidatePool;

    // 2. 남성 음성 키워드 (자연스러운 Neural/Natural/Enhanced 우선순위)
    const maleKeywords = [
      'google uk english male',
      'guy online (natural)',
      'christopher online (natural)',
      'ryan online (natural)',
      'guy neural',
      'christopher neural',
      'nathan',
      'evan',
      'tom',
      'oliver',
      'daniel',
      'george',
      'david',
      'standard-b',
      'standard-d',
      'wavenet-b',
      'wavenet-d',
      'neural2-d',
      'male',
    ];

    // 3. 여성 음성 키워드 (자연스러운 Neural/Natural/Enhanced 우선순위)
    const femaleKeywords = [
      'google us english',
      'jenny online (natural)',
      'aria online (natural)',
      'google uk english female',
      'jenny neural',
      'aria neural',
      'samantha',
      'ava',
      'karen',
      'victoria',
      'zira',
      'standard-a',
      'standard-c',
      'standard-e',
      'wavenet-a',
      'wavenet-c',
      'neural2-c',
      'female',
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

  /// Anki 스타일의 고품질 원어민 오디오 스트림 URL 생성
  String? _getAudioStreamUrl(String text, TtsVoiceGender gender) {
    final clean = text.trim();
    if (clean.isEmpty) return null;

    if (gender == TtsVoiceGender.female) {
      // Anki AwesomeTTS 대표 음원: Google Translate TTS의 부드럽고 자연스러운 미국식 신경망 원음 스트림
      return 'https://translate.google.com/translate_tts?ie=UTF-8&tl=en-US&client=tw-ob&q=${Uri.encodeComponent(clean)}';
    } else {
      // 남성: 단어인 경우 Anki에서 널리 쓰이는 영국식 원어민 스튜디오 녹음 오디오 스트림
      if (!clean.contains(' ')) {
        return 'https://dict.youdao.com/dictvoice?audio=${Uri.encodeComponent(clean)}&type=1';
      }
      // 문장/구문인 경우 Web Speech API의 Google UK English Male 또는 남성 음성으로 처리
      return null;
    }
  }

  /// Anki 스타일 원어민 오디오 스트림 재생 시도 (실패 시 false 반환 후 Web Speech로 폴백)
  Future<bool> _tryPlayAudioStream(String text, TtsVoiceGender gender) async {
    final url = _getAudioStreamUrl(text, gender);
    if (url == null) return false;

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

      // 네트워크 지연/오프라인 방지: 3초 내에 완료되거나 재생되지 않으면 Fallback
      _audioTimeoutTimer = Timer(const Duration(milliseconds: 3000), () {
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

  /// 브라우저 내장 고품질 Web Speech API 재생 (피치 왜곡 없는 순수 원음)
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
      } else {
        utterance.lang = 'en-US';
      }

      // Anki처럼 자연스러운 원음을 위해 피치 왜곡(0.75, 1.15)을 완전히 제거하고 1.0(원음) 적용
      utterance.pitch = 1.0;
      // 사람이 또렷하고 명확하게 낭독하는 최적 속도
      utterance.rate = 0.95;
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

    // 1차: Anki 방식의 자연스러운 원어민 오디오 스트림 재생 시도
    final audioSuccess = await _tryPlayAudioStream(clean, gender);
    if (audioSuccess) {
      return;
    }

    // 2차: 오디오 스트림 실패 또는 문장/구문인 경우 고품질 Web Speech API로 즉시 폴백
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
