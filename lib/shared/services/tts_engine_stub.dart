import 'dart:ui';
import 'tts_engine_base.dart';

class TtsEngineStub implements BaseTtsEngine {
  VoidCallback? _onStart;
  VoidCallback? _onComplete;

  @override
  Future<void> init() async {}

  @override
  Future<void> speak(String text, TtsVoiceGender gender) async {
    _onStart?.call();
    _onComplete?.call();
  }

  @override
  Future<void> stop() async {
    _onComplete?.call();
  }

  @override
  void setHandlers({
    VoidCallback? onStart,
    VoidCallback? onComplete,
    void Function(String msg)? onError,
  }) {
    _onStart = onStart;
    _onComplete = onComplete;
  }
}

BaseTtsEngine createTtsEngine() => TtsEngineStub();
