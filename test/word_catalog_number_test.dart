import 'package:flutter_test/flutter_test.dart';
import 'package:linguistic_cabinet/core/utils/word_catalog_number.dart';
import 'package:linguistic_cabinet/features/words/data/models/word.dart';

/// 카탈로그 번호(CAB · #NNNN)는 단어의 **등록 순서**로 결정되는 식별자다.
/// 정렬 모드나 태그 필터가 바뀌어도 같은 단어의 번호가 달라지면 안 된다.
void main() {
  final base = DateTime(2025, 1, 1);

  Word word(String id, String english, int day, {int? difficulty}) => Word(
        id: id,
        english: english,
        korean: english,
        difficulty: difficulty ?? 3,
        createdAt: base.add(Duration(days: day)),
      );

  group('WordCatalogNumber', () {
    test('등록 순서(오래된 순)로 1-based 번호를 부여한다', () {
      // 리스트 순서와 등록 순서를 일부러 다르게 배치한다.
      final words = [
        word('w3', 'cherry', 3),
        word('w1', 'apple', 1),
        word('w4', 'date', 4),
        word('w2', 'banana', 2),
      ];

      final catalog = WordCatalogNumber.from(words);

      expect(catalog.of(words[1]), 'CAB · #0001', reason: 'apple이 첫 등록');
      expect(catalog.of(words[3]), 'CAB · #0002', reason: 'banana');
      expect(catalog.of(words[0]), 'CAB · #0003', reason: 'cherry');
      expect(catalog.of(words[2]), 'CAB · #0004', reason: 'date');
    });

    test('리스트에 없는 단어는 null을 반환한다', () {
      final catalog = WordCatalogNumber.from([word('w1', 'apple', 1)]);
      final stranger = word('other', 'zzz', 9);

      expect(catalog.of(stranger), isNull);
    });

    test('createdAt이 같아도 원래 인덱스로 결정적으로 정렬된다', () {
      // 동시 import로 createdAt이 동일한 경우 — 결과가 매번 같아야 한다.
      final words = [
        word('a', 'first', 1),
        word('b', 'second', 1),
        word('c', 'third', 1),
      ];

      final catalog = WordCatalogNumber.from(words);

      expect(catalog.of(words[0]), 'CAB · #0001');
      expect(catalog.of(words[1]), 'CAB · #0002');
      expect(catalog.of(words[2]), 'CAB · #0003');

      // 같은 입력을 반복해도 동일해야 한다 (비결정적 정렬 방지).
      final again = WordCatalogNumber.from(words);
      expect(again.of(words[0]), 'CAB · #0001');
      expect(again.of(words[1]), 'CAB · #0002');
      expect(again.of(words[2]), 'CAB · #0003');
    });

    test('정렬 모드가 바뀌어도 같은 단어의 번호는 동일하다', () {
      final words = [
        word('w1', 'apple', 1, difficulty: 5),
        word('w2', 'banana', 2, difficulty: 1),
        word('w3', 'cherry', 3, difficulty: 4),
        word('w4', 'date', 4, difficulty: 2),
      ];

      // 정렬 모드 3종을 흉내낸다 (word_list_screen의 정렬 로직과 동일).
      List<Word> applySort(String mode) {
        final sorted = List<Word>.from(words);
        if (mode == 'alpha') {
          sorted.sort((a, b) => a.english.toLowerCase().compareTo(b.english.toLowerCase()));
        } else if (mode == 'mastery') {
          sorted.sort((a, b) => a.difficulty.compareTo(b.difficulty));
        } else {
          sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        }
        return sorted;
      }

      // 번호는 정렬 결과의 position이 아니라 등록 순서로 결정된다.
      // 단어별 기대 번호는 등록 순서(apple=1, banana=2, cherry=3, date=4) 기준.
      final expectedByEnglish = {
        'apple': 'CAB · #0001',
        'banana': 'CAB · #0002',
        'cherry': 'CAB · #0003',
        'date': 'CAB · #0004',
      };

      final catalog = WordCatalogNumber.from(words);

      // 정렬 모드마다 배치 순서는 달라지지만, 단어별 번호는 같아야 한다.
      final ordersByMode = <String, List<String>>{};
      for (final mode in ['alpha', 'mastery', 'recent']) {
        ordersByMode[mode] = applySort(mode).map((w) => w.english).toList();
        for (final w in applySort(mode)) {
          expect(catalog.of(w), expectedByEnglish[w.english], reason: '$mode 정렬의 ${w.english}');
        }
      }

      // 각 정렬 모드가 실제로 서로 다른 배치를 만들는지 sanity check —
      // 모두 같은 배열이면 위 검증이 무의미해진다.
      expect(ordersByMode['alpha'], isNot(equals(ordersByMode['mastery'])));
      expect(ordersByMode['mastery'], isNot(equals(ordersByMode['recent'])));
    });

    test('태그 필터로 일부 단어가 빠져도 남은 단어의 번호는 변하지 않는다', () {
      final all = [
        word('w1', 'apple', 1),
        word('w2', 'banana', 2),
        word('w3', 'cherry', 3),
      ];

      // 전체 목록 기준 번호 (실제 앱이 쓰는 기준)
      final fullCatalog = WordCatalogNumber.from(all);
      expect(fullCatalog.of(all[2]), 'CAB · #0003');

      // cherry만 남은 부분 리스트에서 번호를 새로 만들면 #0001로 틀어진다 —
      // 그래서 화면은 부분 리스트가 아니라 전체 목록으로 번호를 만들어야 한다.
      final filteredCatalog = WordCatalogNumber.from([all[2]]);
      expect(filteredCatalog.of(all[2]), 'CAB · #0001');
      expect(
        filteredCatalog.of(all[2]),
        isNot(fullCatalog.of(all[2])),
        reason: '부분 리스트 기준 번호는 전체 목록 기준과 어긋난다 (회귀 근거)',
      );
    });

    test('포맷 헬퍼는 4자리 0 패딩을 유지한다', () {
      expect(WordCatalogNumber.format(1), 'CAB · #0001');
      expect(WordCatalogNumber.format(42), 'CAB · #0042');
      expect(WordCatalogNumber.format(1234), 'CAB · #1234');
      expect(WordCatalogNumber.formatBare(7), '#0007');
    });

    test('빈 리스트와 단일 단어도 안전하게 처리한다', () {
      final empty = WordCatalogNumber.from([]);
      expect(empty.of(word('x', 'x', 1)), isNull);

      final single = WordCatalogNumber.from([word('only', 'only', 1)]);
      expect(single.of(word('only', 'only', 1)), 'CAB · #0001');
    });
  });
}
