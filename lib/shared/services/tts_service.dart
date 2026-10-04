import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../features/review/data/repositories/review_repository.dart';
import '../../features/review/presentation/screens/review_screen.dart';
import '../../core/theme/cabinet_colors.dart';
import '../../core/theme/cabinet_theme.dart';

/// 발음 음성 성별 (여성 / 남성)
enum TtsVoiceGender {
  female('여성', 'Female', '♀', 1.15),
  male('남성', 'Male', '♂', 0.85);

  final String labelKo;
  final String labelEn;
  final String symbol;
  final double defaultPitch;
  const TtsVoiceGender(this.labelKo, this.labelEn, this.symbol, this.defaultPitch);

  static TtsVoiceGender fromString(String? val) {
    if (val == 'male') return TtsVoiceGender.male;
    return TtsVoiceGender.female;
  }
}

/// 기본 음성 성별 설정 관리 Provider
final ttsVoiceGenderProvider =
    StateNotifierProvider<TtsVoiceGenderNotifier, TtsVoiceGender>((ref) {
  final repo = ref.watch(reviewRepositoryProvider);
  return TtsVoiceGenderNotifier(repo);
});

class TtsVoiceGenderNotifier extends StateNotifier<TtsVoiceGender> {
  final ReviewRepository _repo;
  static const String settingKey = 'tts_voice_gender';

  TtsVoiceGenderNotifier(this._repo) : super(TtsVoiceGender.female) {
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    try {
      final saved = await _repo.getSetting(settingKey);
      if (saved != null) {
        state = TtsVoiceGender.fromString(saved);
      }
    } catch (_) {}
  }

  Future<void> setGender(TtsVoiceGender gender) async {
    state = gender;
    try {
      await _repo.setSetting(settingKey, gender.name);
    } catch (_) {}
  }
}

/// TTS 발음 재생 서비스 Provider
final ttsServiceProvider = Provider<TtsService>((ref) {
  final service = TtsService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

class TtsService {
  final FlutterTts _tts;
  bool _isInitialized = false;
  bool _isPlaying = false;
  String? _currentlySpeakingWord;
  TtsVoiceGender? _currentSpeakingGender;
  List<Map<String, String>> _availableVoices = [];

  TtsService({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  bool get isPlaying => _isPlaying;
  String? get currentlySpeakingWord => _currentlySpeakingWord;
  TtsVoiceGender? get currentSpeakingGender => _currentSpeakingGender;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      await _tts.setLanguage("en-US");
      // 웹에서는 0.9가 자연스럽고, 모바일/데스크톱에서는 0.48이 학습용 적정 속도
      await _tts.setSpeechRate(kIsWeb ? 0.9 : 0.48);
      await _tts.setVolume(1.0);

      _tts.setStartHandler(() {
        _isPlaying = true;
      });
      _tts.setCompletionHandler(() {
        _isPlaying = false;
        _currentlySpeakingWord = null;
        _currentSpeakingGender = null;
      });
      _tts.setCancelHandler(() {
        _isPlaying = false;
        _currentlySpeakingWord = null;
        _currentSpeakingGender = null;
      });
      _tts.setErrorHandler((msg) {
        _isPlaying = false;
        _currentlySpeakingWord = null;
        _currentSpeakingGender = null;
        debugPrint('TTS Error: $msg');
      });

      await _loadVoices();
      _isInitialized = true;
    } catch (e) {
      debugPrint('TTS init warning (plugin might be unavailable in tests): $e');
    }
  }

  Future<void> _loadVoices() async {
    try {
      final voices = await _tts.getVoices;
      if (voices is List) {
        _availableVoices = voices
            .whereType<Map>()
            .map((v) => v.map((key, value) => MapEntry(key.toString(), value.toString())))
            .toList();
      }
    } catch (e) {
      debugPrint('TTS getVoices error: $e');
    }
  }

  /// 단어 텍스트를 지정한 성별(남성/여성) 음성으로 발음 재생
  Future<void> speak(String text, {TtsVoiceGender gender = TtsVoiceGender.female}) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    try {
      await init();
      await stop();

      // 1. 성별에 최적화된 보이스 매칭
      final targetVoice = _findVoiceForGender(gender);
      if (targetVoice != null && targetVoice['name'] != null) {
        await _tts.setVoice({
          'name': targetVoice['name']!,
          'locale': targetVoice['locale'] ?? 'en-US',
        });
      }

      // 2. 피치(음조)를 결합하여 OS/브라우저 엔진에 관계없이 뚜렷한 남/여 톤 보장
      await _tts.setPitch(gender.defaultPitch);

      _currentlySpeakingWord = cleanText;
      _currentSpeakingGender = gender;
      _isPlaying = true;
      await _tts.speak(cleanText);
    } catch (e) {
      debugPrint('TTS speak failed: $e');
      _isPlaying = false;
      _currentlySpeakingWord = null;
      _currentSpeakingGender = null;
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
    _isPlaying = false;
    _currentlySpeakingWord = null;
    _currentSpeakingGender = null;
  }

  Map<String, String>? _findVoiceForGender(TtsVoiceGender gender) {
    if (_availableVoices.isEmpty) return null;

    final englishVoices = _availableVoices.where((v) {
      final loc = (v['locale'] ?? v['lang'] ?? '').toLowerCase();
      return loc.startsWith('en');
    }).toList();

    final candidates = englishVoices.isNotEmpty ? englishVoices : _availableVoices;

    if (gender == TtsVoiceGender.male) {
      const maleKeywords = [
        'male', 'david', 'alex', 'guy', 'james', 'george', 'daniel', 'fred',
        'brian', 'tom', 'mark', 'aaron', 'standard-b', 'standard-d', 'wavenet-b',
        'wavenet-d', 'neural2-d', 'neural2-j'
      ];
      for (final v in candidates) {
        final name = (v['name'] ?? '').toLowerCase();
        final g = (v['gender'] ?? '').toLowerCase();
        if (g == 'male' || maleKeywords.any((k) => name.contains(k))) {
          return v;
        }
      }
    } else {
      const femaleKeywords = [
        'female', 'samantha', 'zira', 'jenny', 'victoria', 'karen', 'susan',
        'allison', 'joanna', 'kendra', 'standard-a', 'standard-c', 'standard-e',
        'wavenet-a', 'wavenet-c', 'neural2-c', 'neural2-f'
      ];
      for (final v in candidates) {
        final name = (v['name'] ?? '').toLowerCase();
        final g = (v['gender'] ?? '').toLowerCase();
        if (g == 'female' || femaleKeywords.any((k) => name.contains(k))) {
          return v;
        }
      }
    }

    return candidates.isNotEmpty ? candidates.first : null;
  }

  void dispose() {
    stop();
  }
}

/// 단어 발음을 남성/여성 음성으로 즉시 들을 수 있는 캐비닛 스타일 버튼 위젯
class CabinetPronounceButtons extends ConsumerStatefulWidget {
  final String word;
  final CabinetColors colors;
  final CabinetTheme theme;
  final bool compact;
  final Color? activeColor;

  const CabinetPronounceButtons({
    super.key,
    required this.word,
    required this.colors,
    required this.theme,
    this.compact = false,
    this.activeColor,
  });

  @override
  ConsumerState<CabinetPronounceButtons> createState() =>
      _CabinetPronounceButtonsState();
}

class _CabinetPronounceButtonsState
    extends ConsumerState<CabinetPronounceButtons> {
  TtsVoiceGender? _activeGender;

  void _speak(TtsVoiceGender gender) async {
    final tts = ref.read(ttsServiceProvider);
    setState(() {
      _activeGender = gender;
    });
    await tts.speak(widget.word, gender: gender);
    if (mounted) {
      setState(() {
        _activeGender = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cleanWord = widget.word.trim();
    final isEnabled = cleanWord.isNotEmpty;

    if (widget.compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCompactBtn(TtsVoiceGender.female, isEnabled),
          const SizedBox(width: 6),
          _buildCompactBtn(TtsVoiceGender.male, isEnabled),
        ],
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildFullBtn(TtsVoiceGender.female, isEnabled),
        _buildFullBtn(TtsVoiceGender.male, isEnabled),
      ],
    );
  }

  Widget _buildCompactBtn(TtsVoiceGender gender, bool isEnabled) {
    final isPlaying = _activeGender == gender;
    final btnColor = widget.activeColor ?? widget.colors.accent;

    return InkWell(
      onTap: isEnabled ? () => _speak(gender) : null,
      borderRadius: BorderRadius.circular(3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isPlaying
              ? btnColor.withValues(alpha: 0.15)
              : widget.colors.paper3,
          border: Border.all(
            color: isPlaying
                ? btnColor
                : widget.colors.inkLineStrong,
            width: isPlaying ? 1.4 : 1.0,
          ),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPlaying ? Icons.volume_up : Icons.volume_down_outlined,
              size: 13,
              color: isPlaying ? btnColor : widget.colors.ink2,
            ),
            const SizedBox(width: 4),
            Text(
              '${gender.symbol} ${gender.labelKo}',
              style: widget.theme.labelMono.copyWith(
                fontSize: 11,
                fontWeight: isPlaying ? FontWeight.w700 : FontWeight.w500,
                color: isPlaying ? btnColor : widget.colors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullBtn(TtsVoiceGender gender, bool isEnabled) {
    final isPlaying = _activeGender == gender;
    final btnColor = widget.activeColor ?? widget.colors.accent;

    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: isPlaying ? btnColor : widget.colors.ink,
        backgroundColor: isPlaying
            ? btnColor.withValues(alpha: 0.12)
            : widget.colors.paper3,
        side: BorderSide(
          color: isPlaying
              ? btnColor
              : widget.colors.inkLineStrong,
          width: isPlaying ? 1.5 : 1.0,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      ),
      icon: Icon(
        isPlaying ? Icons.volume_up : Icons.volume_down,
        size: 16,
        color: isPlaying ? btnColor : widget.colors.ink2,
      ),
      label: Text(
        '${gender.symbol} ${gender.labelKo} 발음 (${gender.labelEn})',
        style: widget.theme.labelMono.copyWith(
          fontSize: 11,
          fontWeight: isPlaying ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
      onPressed: isEnabled ? () => _speak(gender) : null,
    );
  }
}
