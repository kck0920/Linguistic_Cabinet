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

/// 플랫폼별 음성 목록에서 남성/여성 영어 음성을 일관되게 판별하는 공통 리졸버
class TtsVoiceCandidate {
  final String name;
  final String localeOrLang;
  final String gender;

  const TtsVoiceCandidate({
    required this.name,
    required this.localeOrLang,
    this.gender = '',
  });
}

class TtsVoiceResolver {
  TtsVoiceResolver._();

  static const List<String> robotBlacklist = [
    'fred', 'albert', 'ralph', 'bad news', 'bahh', 'bells', 'boing',
    'bubbles', 'cellos', 'deranged', 'good news', 'hysterical',
    'pipe organ', 'trinoids', 'whisper', 'zarvox', 'junior',
    'princess', 'espeak',
  ];

  static const List<String> femaleExclusiveKeywords = [
    'female', 'woman', 'girl', 'samantha', 'karen', 'victoria', 'zira',
    'jenny', 'aria', 'flo', 'ava', 'shelley', 'sandy', 'grandma',
    'kathy', 'fiona', 'moira', 'tessa', 'veena', 'yuri', 'catherine',
    'allison', 'susan', 'kate', 'serena', 'google us english',
    'en-us-x-sfg', 'en-us-x-tpf', 'en-us-x-iob', 'en-us-x-iol',
    'en-gb-x-gba', 'en-gb-x-gbc', 'en-au-x-aua', 'en-au-x-auc',
  ];

  static const List<String> maleKeywords = [
    'google uk english male',
    'guy online (natural)',
    'christopher online (natural)',
    'ryan online (natural)',
    'andrew online (natural)',
    'brian online (natural)',
    'eric online (natural)',
    'roger online (natural)',
    'steffan online (natural)',
    'guy neural',
    'christopher neural',
    'en-us-x-iom',
    'en-us-x-tpd',
    'en-gb-x-gbd',
    'en-gb-x-rjs',
    'en-au-x-aud',
    'en-au-x-aub',
    'nathan',
    'evan',
    'tom',
    'oliver',
    'daniel',
    'alex',
    'aaron',
    'arthur',
    'gordon',
    'lee',
    'rishi',
    'eddy',
    'reed',
    'rocko',
    'grandpa',
    'george',
    'david',
    'mark',
    'james',
    'richard',
    'standard-b',
    'standard-d',
    'wavenet-b',
    'wavenet-d',
    'neural2-d',
    'neural2-b',
    'male',
  ];

  static const List<String> femaleKeywords = [
    'google us english',
    'jenny online (natural)',
    'aria online (natural)',
    'google uk english female',
    'jenny neural',
    'aria neural',
    'en-us-x-sfg',
    'en-us-x-tpf',
    'en-us-x-iob',
    'en-us-x-iol',
    'en-gb-x-gba',
    'en-gb-x-gbc',
    'en-au-x-aua',
    'en-au-x-auc',
    'samantha',
    'ava',
    'karen',
    'victoria',
    'zira',
    'allison',
    'susan',
    'kate',
    'moira',
    'tessa',
    'fiona',
    'standard-a',
    'standard-c',
    'standard-e',
    'wavenet-a',
    'wavenet-c',
    'neural2-c',
    'female',
  ];

  static final RegExp _maleWordRegex = RegExp(r'\bmale\b');

  static bool _isFemaleVoice(TtsVoiceCandidate v) {
    final name = v.name.toLowerCase();
    final g = v.gender.toLowerCase();
    return g == 'female' || femaleExclusiveKeywords.any((fk) => name.contains(fk));
  }

  /// 후보 목록에서 (maleIndex, femaleIndex)를 반환한다. 찾지 못하면 null.
  static ({int? maleIndex, int? femaleIndex}) resolve(List<TtsVoiceCandidate> voices) {
    if (voices.isEmpty) return (maleIndex: null, femaleIndex: null);

    final validIndices = <int>[];
    for (int i = 0; i < voices.length; i++) {
      final name = voices[i].name.toLowerCase();
      if (!robotBlacklist.any((kw) => name.contains(kw))) {
        validIndices.add(i);
      }
    }
    final candidateIndices = validIndices.isNotEmpty
        ? validIndices
        : List<int>.generate(voices.length, (i) => i);

    final englishIndices = candidateIndices
        .where((i) => voices[i].localeOrLang.toLowerCase().startsWith('en'))
        .toList();
    final pool = englishIndices.isNotEmpty ? englishIndices : candidateIndices;

    int? foundMale;
    for (final i in pool) {
      if (voices[i].gender.toLowerCase() == 'male' && !_isFemaleVoice(voices[i])) {
        foundMale = i;
        break;
      }
    }

    if (foundMale == null) {
      for (final kw in maleKeywords) {
        for (final i in pool) {
          final v = voices[i];
          if (_isFemaleVoice(v)) continue;
          final name = v.name.toLowerCase();
          final matched = (kw == 'male') ? _maleWordRegex.hasMatch(name) : name.contains(kw);
          if (matched) {
            foundMale = i;
            break;
          }
        }
        if (foundMale != null) break;
      }
    }

    int? foundFemale;
    for (final i in pool) {
      if (voices[i].gender.toLowerCase() == 'female') {
        foundFemale = i;
        break;
      }
    }

    if (foundFemale == null) {
      for (final kw in femaleKeywords) {
        for (final i in pool) {
          final v = voices[i];
          if (v.gender.toLowerCase() == 'male') continue;
          if (v.name.toLowerCase().contains(kw)) {
            foundFemale = i;
            break;
          }
        }
        if (foundFemale != null) break;
      }
    }

    if (foundFemale == null && pool.isNotEmpty) {
      foundFemale = pool.firstWhere(
        (i) => i != foundMale,
        orElse: () => pool.first,
      );
    }

    if (foundMale == null && pool.isNotEmpty) {
      for (final i in pool) {
        if (i != foundFemale && !_isFemaleVoice(voices[i])) {
          foundMale = i;
          break;
        }
      }
    }

    return (maleIndex: foundMale, femaleIndex: foundFemale);
  }
}
