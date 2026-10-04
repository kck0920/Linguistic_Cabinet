import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/review/data/repositories/review_repository.dart';
import '../../features/review/presentation/screens/review_screen.dart';
import '../../core/theme/cabinet_colors.dart';
import '../../core/theme/cabinet_theme.dart';
import 'tts_engine_base.dart';
import 'tts_engine.dart';

export 'tts_engine_base.dart' show TtsVoiceGender, BaseTtsEngine;

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
  final engine = createTtsEngine();
  final service = TtsService(engine: engine);
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

class TtsService {
  final BaseTtsEngine _engine;
  bool _isPlaying = false;
  String? _currentlySpeakingWord;
  TtsVoiceGender? _currentSpeakingGender;

  TtsService({BaseTtsEngine? engine})
      : _engine = engine ?? createTtsEngine() {
    _engine.setHandlers(
      onStart: () {
        _isPlaying = true;
      },
      onComplete: () {
        _isPlaying = false;
        _currentlySpeakingWord = null;
        _currentSpeakingGender = null;
      },
      onError: (msg) {
        _isPlaying = false;
        _currentlySpeakingWord = null;
        _currentSpeakingGender = null;
      },
    );
  }

  bool get isPlaying => _isPlaying;
  String? get currentlySpeakingWord => _currentlySpeakingWord;
  TtsVoiceGender? get currentSpeakingGender => _currentSpeakingGender;

  Future<void> init() async {
    await _engine.init();
  }

  /// 단어 텍스트를 지정한 성별(남성/여성) 음성으로 발음 재생
  Future<void> speak(String text, {TtsVoiceGender gender = TtsVoiceGender.female}) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    try {
      _currentlySpeakingWord = cleanText;
      _currentSpeakingGender = gender;
      _isPlaying = true;
      await _engine.speak(cleanText, gender);
    } catch (e) {
      debugPrint('TTS speak error: $e');
      _isPlaying = false;
      _currentlySpeakingWord = null;
      _currentSpeakingGender = null;
    }
  }

  Future<void> stop() async {
    try {
      await _engine.stop();
    } catch (_) {}
    _isPlaying = false;
    _currentlySpeakingWord = null;
    _currentSpeakingGender = null;
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
