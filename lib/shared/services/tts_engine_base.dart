import 'dart:ui';

enum TtsVoiceGender {
  female('여성', 'Female', '♀', 1.0),
  male('남성', 'Male', '♂', 1.0);

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

abstract class BaseTtsEngine {
  Future<void> init();
  Future<void> speak(String text, TtsVoiceGender gender);
  Future<void> stop();
  void setHandlers({
    VoidCallback? onStart,
    VoidCallback? onComplete,
    void Function(String msg)? onError,
  });
}
