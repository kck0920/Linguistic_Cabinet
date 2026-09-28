import '../../features/words/data/models/word.dart';
import 'word_catalog_number.dart';

/// 30분 단위 슬롯 길이(밀리초). 오늘의 단어가 이 간격으로 교체된다.
const wordOfDaySlot = Duration(minutes: 30);

/// "오늘의 단어"를 결정적으로 고르는 단일 진실 원천.
///
/// 예전에는 `getAllWords()`가 돌려준 순서(= DB rowid 순서)에 대해
/// `words[slot % words.length]`를 그대로 적용했다. rowid 순서는
/// 단어 추가/삭제/백업 복원/import 시점에 따라 달라져, **같은 슬롯인데
/// 다른 단어가 노출**되는 일이 있었다.
///
/// 여기서는 [WordCatalogNumber.registrationOrder]로 정렬한 등록 순서를 쓰므로
/// 같은 단어 집합에서는 슬롯 -> 단어 대응이 언제나 동일하다.
///
/// 결정성 보장을 위해 [now]는 주입 가능(테스트에서 시계를 고정).
class WordOfDayPicker {
  const WordOfDayPicker._();

  /// 현재 시각 기준 30분 슬롯 번호.
  static int slotOf(DateTime now) =>
      now.millisecondsSinceEpoch ~/ wordOfDaySlot.inMilliseconds;

  /// [slot] 슬롯에 보여줄 단어를 반환한다. 단어가 없으면 null.
  ///
  /// 정렬 비용을 아끼려면 호출부에서 이미
  /// `WordCatalogNumber.registrationOrder(words)`로 정렬한 [ordered]를 넘길 수 있다.
  static Word? pick(List<Word> words, int slot) =>
      pickFromOrdered(WordCatalogNumber.registrationOrder(words), slot);

  /// 이미 등록 순서로 정렬된 리스트에서 슬롯에 해당하는 단어를 고른다.
  static Word? pickFromOrdered(List<Word> ordered, int slot) {
    if (ordered.isEmpty) return null;
    // 음수 슬롯(과거 epoch 등)에도 인덱스 오류가 나지 않도록 나머지를 정규화한다.
    final index = slot % ordered.length;
    return ordered[index < 0 ? index + ordered.length : index];
  }

  /// [now] 시각 기준으로 [words] 중 오늘의 단어를 고른다.
  static Word? pickForNow(List<Word> words, DateTime now) =>
      pick(words, slotOf(now));
}
