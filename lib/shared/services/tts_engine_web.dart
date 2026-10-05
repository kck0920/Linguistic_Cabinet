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

    // 여성 음성 키워드 (남성 음성 매칭 시 엄격 배제용)
    const femaleExclusiveKeywords = [
      'female', 'woman', 'samantha', 'karen', 'victoria', 'zira',
      'jenny', 'aria', 'flo', 'ava', 'shelley', 'sandy', 'grandma',
      'kathy', 'fiona', 'moira', 'tessa', 'veena', 'yuri', 'catherine'
    ];

    // 남성 음성 키워드 (우선순위 순서)
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

    // 여성 음성 키워드 (우선순위 순서)
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

    // 남성 보이스 탐색: 여성 키워드가 포함된 음성은 절대 선택하지 않음!
    web.SpeechSynthesisVoice? foundMale;
    for (final kw in maleKeywords) {
      for (final v in pool) {
        final name = v.name.toLowerCase();
        final isFemale = femaleExclusiveKeywords.any((fk) => name.contains(fk));
        if (!isFemale && name.contains(kw)) {
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

    // 여성 보이스를 못 찾았을 경우만 풀에서 배정 (남성은 엉뚱한 여성 보이스로 덮어쓰지 않음)
    if (foundFemale == null && pool.isNotEmpty) {
      foundFemale = pool.firstWhere(
        (v) => v != foundMale,
        orElse: () => pool.first,
      );
    }

    _cachedMaleVoice = foundMale;
    _cachedFemaleVoice = foundFemale;
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
    // 단어뿐만 아니라 아무리 긴 문장도 끊김 없이 100% 네이티브 유려한 성우 음성으로 재생
    urls.add('/api/tts?text=$encoded&gender=${gender.name}');

    // 2순위 (오프라인 / 로컬 개발 환경 폴백):
    if (gender == TtsVoiceGender.female) {
      urls.add('https://translate.google.com/translate_tts?ie=UTF-8&tl=en-US&client=tw-ob&q=$encoded');
    } else {
      if (!clean.contains(' ')) {
        urls.add('https://dict.youdao.com/dictvoice?audio=$encoded&type=1');
      }
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
      } else {
        utterance.lang = 'en-US';
      }

      // 자연스러운 원음을 위해 피치 왜곡 없이 1.0(원음) 적용
      utterance.pitch = 1.0;
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

    // 1차: 최고급 원어민 네이티브 오디오 스트림 재생 시도 (단어 및 예문 문장 모두 지원)
    final audioSuccess = await _tryPlayAudioStream(clean, gender);
    if (audioSuccess) {
      return;
    }

    // 2차: 오디오 스트림 실패 시 Web Speech API 폴백
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
