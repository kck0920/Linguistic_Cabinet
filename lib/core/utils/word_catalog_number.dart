import '../../features/words/data/models/word.dart';

/// 카탈로그 번호(CAB · #NNNN) 계산의 단일 진실 원천.
///
/// 번호는 단어의 **등록 순서**(createdAt 오름차순, 동률 시 원래 리스트 인덱스
/// 오름차순)로 결정된다. 따라서 정렬 모드(알파벳/숙달/최신)나 태그 필터가
/// 바뀌어도 같은 단어의 번호는 변하지 않는다.
///
/// 성능: 정렬 1회 + 순회 1회로 끝나는 O(n log n).
/// `List.indexOf`를 정렬 비교자 안에서 호출하는 O(n² log n) 패턴을 쓰지 않는다.
class WordCatalogNumber {
  const WordCatalogNumber._(this._numberById);

  /// 단어 id -> 1-based 등록 순번
  final Map<String, int> _numberById;

  /// [words]를 등록 순서(오래된 순)로 정렬해 단어별 카탈로그 번호를 만든다.
  ///
  /// createdAt이 동일한 경우(동시 import 등)에는 [words]에서의 원래 위치를
  /// 2차 기준으로 삼아 결과가 결정적이 되도록 한다.
  factory WordCatalogNumber.from(List<Word> words) {
    final ordered = registrationOrder(words);
    final numberById = <String, int>{};
    for (var rank = 0; rank < ordered.length; rank++) {
      numberById[ordered[rank].id] = rank + 1;
    }
    return WordCatalogNumber._(numberById);
  }

  /// [words]를 **등록 순서**(createdAt 오름차순, 동률 시 원래 인덱스 오름차순)
  /// 로 정렬한 새 리스트를 반환한다. 입력 리스트는 변경하지 않는다.
  ///
  /// 카탈로그 번호 부여 순서와 "오늘의 단어" 선택 순서를 일치시키기 위해
  /// 두 곳이 이 메서드를 공유한다(단일 진실 원천).
  ///
  /// 성능: 정렬 1회 O(n log n). 비교자는 튜플 필드만 읽으므로 O(n²) 패턴이 없다.
  static List<Word> registrationOrder(List<Word> words) {
    // (단어, 원래 인덱스)를 함께 정렬 — 비교자는 두 값만으로 결정된다.
    final indexed = List<(Word, int)>.generate(
      words.length,
      (i) => (words[i], i),
      growable: false,
    );
    indexed.sort((a, b) {
      final byCreatedAt = a.$1.createdAt.compareTo(b.$1.createdAt);
      if (byCreatedAt != 0) return byCreatedAt;
      return a.$2.compareTo(b.$2);
    });
    return [for (final entry in indexed) entry.$1];
  }

  /// [word]의 'CAB · #0007' 형태 번호 문자열. 등록 순서를 알 수 없으면 null.
  String? of(Word word) {
    final number = _numberById[word.id];
    return number == null ? null : format(number);
  }

  /// [word]의 '#0007' 형태 번호 문자열(접두사 없음). 등록 순서를 알 수 없으면 null.
  String? ofBare(Word word) {
    final number = _numberById[word.id];
    return number == null ? null : formatBare(number);
  }

  /// 1-based [number]를 'CAB · #0007' 형태로 포맷한다.
  static String format(int number) => _pad(number, prefix: 'CAB · ');

  /// 1-based [number]를 '#0007' 형태로 포맷한다 (접두사 없음).
  static String formatBare(int number) => _pad(number);

  static String _pad(int number, {String prefix = ''}) {
    final safe = number < 1 ? 1 : number;
    return '$prefix#${safe.toString().padLeft(4, '0')}';
  }
}
