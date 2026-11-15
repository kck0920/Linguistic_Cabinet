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
    // macOS Eloquence 구형 기계음 계열 차단
    'eddy', 'reed', 'rocko', 'grandpa', 'shelley', 'sandy', 'grandma',
    'flo', 'kathy',
  ];

  static const List<String> femaleExclusiveKeywords = [
    'female', 'woman', 'girl', 'samantha', 'karen', 'victoria', 'zira',
    'jenny', 'aria', 'ava', 'emma', 'ana', 'michelle', 'monica',
    'allison', 'susan', 'kate', 'serena', 'moira', 'tessa', 'fiona',
    'veena', 'yuri', 'catherine', 'nicky', 'google us english',
    'en-us-x-sfg', 'en-us-x-tpf', 'en-us-x-iob', 'en-us-x-iol',
    'en-gb-x-gba', 'en-gb-x-gbc', 'en-au-x-aua', 'en-au-x-auc',
  ];

  static const List<String> maleKeywords = [
    // 1. 미국식(en-US) 최고급 Neural / Natural / Multilingual 음성 우선
    'andrewmultilingual online (natural)',
    'brianmultilingual online (natural)',
    'andrew online (natural)',
    'brian online (natural)',
    'guy online (natural)',
    'christopher online (natural)',
    'eric online (natural)',
    'roger online (natural)',
    'steffan online (natural)',
    'davis online (natural)',
    'jason online (natural)',
    'tony online (natural)',
    'andrew neural',
    'brian neural',
    'guy neural',
    'christopher neural',
    'en-us-x-iom',
    'en-us-x-tpd',
    'alex',
    'aaron',
    'evan',
    'nathan',
    'tom',
    'david',
    'mark',
    // 2. 그 외 고품질 영어 남성 음성 (en-GB / en-AU 등 폴백)
    'google uk english male',
    'ryan online (natural)',
    'en-gb-x-gbd',
    'en-gb-x-rjs',
    'en-au-x-aud',
    'en-au-x-aub',
    'daniel',
    'oliver',
    'arthur',
    'george',
    'james',
    'richard',
    'gordon',
    'lee',
    'rishi',
    'standard-b',
    'standard-d',
    'wavenet-b',
    'wavenet-d',
    'neural2-d',
    'neural2-b',
    'male',
  ];

  static const List<String> femaleKeywords = [
    // 1. 미국식(en-US) 최고급 Neural / Natural / Multilingual 음성 우선
    'avamultilingual online (natural)',
    'emmamultilingual online (natural)',
    'jenny online (natural)',
    'aria online (natural)',
    'ava online (natural)',
    'emma online (natural)',
    'ana online (natural)',
    'michelle online (natural)',
    'monica online (natural)',
    'google us english',
    'jenny neural',
    'aria neural',
    'ava neural',
    'emma neural',
    'en-us-x-sfg',
    'en-us-x-tpf',
    'en-us-x-iob',
    'en-us-x-iol',
    'samantha',
    'ava',
    'allison',
    'susan',
    'victoria',
    'zira',
    'nicky',
    // 2. 그 외 고품질 영어 여성 음성 (en-GB / en-AU 등 폴백)
    'google uk english female',
    'en-gb-x-gba',
    'en-gb-x-gbc',
    'en-au-x-aua',
    'en-au-x-auc',
    'karen',
    'kate',
    'moira',
    'tessa',
    'fiona',
    'serena',
    'standard-a',
    'standard-c',
    'standard-e',
    'wavenet-a',
    'wavenet-c',
    'neural2-c',
    'female',
  ];

  static final RegExp _maleWordRegex = RegExp(r'\bmale\b');

  static bool _isUsEnglish(String localeOrLang) {
    final norm = localeOrLang.toLowerCase().replaceAll('_', '-');
    return norm == 'en-us' || norm.startsWith('en-us-');
  }

  static int _naturalQualityScore(TtsVoiceCandidate v) {
    final name = v.name.toLowerCase();
    int score = 0;
    if (name.contains('multilingual') || name.contains('natural') || name.contains('neural')) {
      score += 40;
    }
    if (name.contains('online') || name.contains('enhanced') || name.contains('premium')) {
      score += 30;
    }
    if (name.contains('google') || name.contains('siri')) {
      score += 20;
    }
    if (_isUsEnglish(v.localeOrLang)) {
      score += 10;
    }
    return score;
  }

  static bool _isFemaleVoice(TtsVoiceCandidate v) {
    final name = v.name.toLowerCase();
    final g = v.gender.toLowerCase();
    return g == 'female' || femaleExclusiveKeywords.any((fk) => name.contains(fk));
  }

  /// 후보 목록에서 (maleIndex, femaleIndex)를 반환한다. 찾지 못하면 null.
  /// 자연스러운 Neural/Natural/Enhanced 음성과 미국식(en-US) 발음을 최우선으로 선택한다.
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
    final pool = List<int>.from(englishIndices.isNotEmpty ? englishIndices : candidateIndices);

    // 고품질 자연음 + 미국식(en-US) 순으로 정렬
    pool.sort((a, b) => _naturalQualityScore(voices[b]).compareTo(_naturalQualityScore(voices[a])));

    final usPool = pool.where((i) => _isUsEnglish(voices[i].localeOrLang)).toList();

    int? findMaleIn(List<int> targetPool) {
      for (final i in targetPool) {
        if (voices[i].gender.toLowerCase() == 'male' && !_isFemaleVoice(voices[i])) {
          return i;
        }
      }
      for (final kw in maleKeywords) {
        for (final i in targetPool) {
          final v = voices[i];
          if (_isFemaleVoice(v)) continue;
          final name = v.name.toLowerCase();
          final matched = (kw == 'male') ? _maleWordRegex.hasMatch(name) : name.contains(kw);
          if (matched) return i;
        }
      }
      return null;
    }

    int? findFemaleIn(List<int> targetPool) {
      for (final i in targetPool) {
        if (voices[i].gender.toLowerCase() == 'female') {
          return i;
        }
      }
      for (final kw in femaleKeywords) {
        for (final i in targetPool) {
          final v = voices[i];
          if (v.gender.toLowerCase() == 'male') continue;
          if (v.name.toLowerCase().contains(kw)) return i;
        }
      }
      return null;
    }

    // 미국식(en-US)에서 먼저 탐색하고, 없을 때만 전체 영어 풀로 폴백
    int? foundMale = findMaleIn(usPool) ?? findMaleIn(pool);
    int? foundFemale = findFemaleIn(usPool) ?? findFemaleIn(pool);

    if (foundFemale == null && pool.isNotEmpty) {
      foundFemale = pool.firstWhere(
        (i) => i != foundMale,
        orElse: () => pool.first,
      );
    }

    if (foundMale == null && pool.isNotEmpty) {
      for (final i in usPool) {
        if (i != foundFemale && !_isFemaleVoice(voices[i])) {
          foundMale = i;
          break;
        }
      }
      if (foundMale == null) {
        for (final i in pool) {
          if (i != foundFemale && !_isFemaleVoice(voices[i])) {
            foundMale = i;
            break;
          }
        }
      }
    }

    return (maleIndex: foundMale, femaleIndex: foundFemale);
  }
}
