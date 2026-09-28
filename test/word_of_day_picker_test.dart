import 'package:flutter_test/flutter_test.dart';
import 'package:linguistic_cabinet/core/utils/word_of_day_picker.dart';
import 'package:linguistic_cabinet/features/words/data/models/word.dart';

/// "오늘의 단어"는 30분 슬롯마다 바뀌는데, 같은 슬롯에서 항상 같은 단어가
/// 나와야 한다. 예전 구현은 DB rowid 순서에 의존해 단어 추가/삭제/백업 복원
/// 시 다른 단어가 노출됐었다.
void main() {
  final base = DateTime(2025, 1, 1);

  Word word(String id, String english, int day) => Word(
        id: id,
        english: english,
        korean: english,
        createdAt: base.add(Duration(days: day)),
      );

  group('WordOfDayPicker', () {
    test('DB 반환 순서와 무관하게 등록 순서로 단어를 고른다', () {
      // rowid 순서(apple 마지막)와 등록 순서(apple 첫째)가 뒤집힌 입력.
      final byRowId = [
        word('w3', 'cherry', 3),
        word('w4', 'date', 4),
        word('w2', 'banana', 2),
        word('w1', 'apple', 1),
      ];
      final expected = ['apple', 'banana', 'cherry', 'date'];

      for (var slot = 0; slot < byRowId.length; slot++) {
        expect(
          WordOfDayPicker.pick(byRowId, slot)?.english,
          expected[slot],
          reason: '슬롯 $slot은 등록 순서 $slot번째 단어여야 한다',
        );
      }
    });

    test('입력 리스트 순서가 달라도 같은 슬롯은 같은 단어를 낸다', () {
      final words = [
        word('w1', 'apple', 1),
        word('w2', 'banana', 2),
        word('w3', 'cherry', 3),
      ];
      final shuffled = [words[2], words[0], words[1]];

      for (var slot = 0; slot < 5; slot++) {
        expect(
          WordOfDayPicker.pick(shuffled, slot)?.english,
          WordOfDayPicker.pick(words, slot)?.english,
          reason: '리스트 순서와 무관하게 슬롯 $slot은 동일해야 한다',
        );
      }
    });

    test('중간 단어를 삭제해도 기존 슬롯 결과가 최대한 유지된다', () {
      final before = [
        word('w1', 'apple', 1),
        word('w2', 'banana', 2),
        word('w3', 'cherry', 3),
      ];
      final after = [before[0], before[2]]; // banana 삭제

      // 삭제된 인덱스 이전 슬롯은 등록 순서가 같으므로 그대로 유지된다.
      expect(WordOfDayPicker.pick(after, 0)?.english, 'apple');
      expect(
        WordOfDayPicker.pick(after, 0)?.english,
        WordOfDayPicker.pick(before, 0)?.english,
      );
    });

    test('createdAt이 같은 단어들은 원래 인덱스로 결정적으로 정렬된다', () {
      final sameTime = [
        word('wA', 'first', 0),
        word('wB', 'second', 0),
        word('wC', 'third', 0),
      ];

      expect(WordOfDayPicker.pick(sameTime, 0)?.english, 'first');
      expect(WordOfDayPicker.pick(sameTime, 1)?.english, 'second');
      expect(WordOfDayPicker.pick(sameTime, 2)?.english, 'third');

      // 같은 입력을 여러 번 돌려도 결과가 흔들리지 않는다.
      for (var i = 0; i < 20; i++) {
        expect(WordOfDayPicker.pick(sameTime, 1)?.english, 'second');
      }
    });

    test('빈 리스트와 단일 단어를 안전하게 처리한다', () {
      expect(WordOfDayPicker.pick(const [], 3), isNull);

      final single = [word('w1', 'apple', 1)];
      for (var slot = 0; slot < 7; slot++) {
        expect(WordOfDayPicker.pick(single, slot)?.english, 'apple');
      }
    });

    test('음수 슬롯에서도 범위 오류가 나지 않는다', () {
      final words = [
        word('w1', 'apple', 1),
        word('w2', 'banana', 2),
        word('w3', 'cherry', 3),
      ];

      // Dart의 `%`는 양수 제수에 대해 음이 아닌 나머지를 주므로
      // -1 % 3 == 2, -4 % 3 == 2 다.
      expect(WordOfDayPicker.pick(words, -1)?.english, 'cherry');
      expect(WordOfDayPicker.pick(words, -4)?.english, 'cherry');
      expect(WordOfDayPicker.pick(words, -3)?.english, 'apple');
    });

    test('slotOf는 30분 경계에서만 슬롯을 바꾼다', () {
      final t0 = DateTime.utc(2025, 6, 1, 10, 0, 0);
      final slot = WordOfDayPicker.slotOf(t0);

      expect(WordOfDayPicker.slotOf(t0), slot);
      expect(
        WordOfDayPicker.slotOf(t0.add(const Duration(minutes: 29, seconds: 59))),
        slot,
        reason: '슬롯 중간에서는 바뀌면 안 된다',
      );
      expect(
        WordOfDayPicker.slotOf(t0.add(const Duration(minutes: 30))),
        slot + 1,
        reason: '30분이 지나면 다음 슬롯',
      );
    });

    test('pickForNow은 slotOf와 pick이 결합된 결과와 같다', () {
      final words = [
        word('w1', 'apple', 1),
        word('w2', 'banana', 2),
        word('w3', 'cherry', 3),
      ];
      final now = DateTime.utc(2025, 6, 1, 10, 7, 33);

      expect(
        WordOfDayPicker.pickForNow(words, now)?.english,
        WordOfDayPicker.pick(words, WordOfDayPicker.slotOf(now))?.english,
      );
    });

    test('pickFromOrdered는 이미 정렬된 리스트를 그대로 사용한다', () {
      final ordered = [
        word('w1', 'apple', 1),
        word('w2', 'banana', 2),
      ];

      expect(WordOfDayPicker.pickFromOrdered(ordered, 1)?.english, 'banana');
      expect(WordOfDayPicker.pickFromOrdered(const [], 0), isNull);
    });
  });
}
