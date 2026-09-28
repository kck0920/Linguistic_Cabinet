import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/cabinet_colors.dart';
import '../../core/theme/cabinet_theme.dart';
import '../../core/utils/word_catalog_number.dart';
import '../../shared/widgets/cabinet_widgets.dart';
import '../../features/words/data/models/word.dart';
import '../home_screen.dart';

/// 대시보드 "최근 수집" 가로 스크롤 카드 스트립 (최대 4장).
class DashboardRecentStrip extends ConsumerWidget {
  const DashboardRecentStrip({super.key, required this.words});

  final List<Word> words;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(cabinetThemeModeProvider);
    final colors = CabinetColors.fromMode(themeMode);
    final theme = CabinetTheme(colors);

    // 카탈로그 번호의 단일 진실 원천 (등록 순서 기준)
    final catalog = WordCatalogNumber.from(words);

    // 최근 등록일(createdAt) 기준 내림차순으로 최신 4장 추출.
    // createdAt이 동일한 경우(동시 import 등)에는 원래 리스트의 뒤쪽 단어가
    // 최신으로 취급한다 — 비교자가 (단어, 원래 인덱스)만 보므로 O(n log n)이다.
    final recent = List<(Word, int)>.generate(
      words.length,
      (i) => (words[i], i),
      growable: false,
    )..sort((a, b) {
        final byCreatedAt = b.$1.createdAt.compareTo(a.$1.createdAt);
        if (byCreatedAt != 0) return byCreatedAt;
        return b.$2.compareTo(a.$2);
      });
    final displayWords = recent.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('RECENTLY COLLECTED', style: theme.labelMono),
        const SizedBox(height: 10),
        if (displayWords.isEmpty)
          Text('No recent cards.', style: theme.bodySans)
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(displayWords.length, (index) {
                final w = displayWords[index].$1;
                final rotation = (index % 2 == 0) ? 1.2 : -1.4;
                final catalogNo = catalog.of(w) ?? WordCatalogNumber.format(index + 1);

                return Container(
                  width: 170,
                  margin: const EdgeInsets.only(right: 14),
                  child: CabinetCatalogCard(
                    catalogNo: catalogNo,
                    english: w.english,
                    ipa: w.pronunciation,
                    korean: w.korean,
                    tag: w.tags.isNotEmpty ? w.tags.first : 'GENERAL',
                    mastery: 5 - (w.difficulty - 1).clamp(0, 5),
                    colors: colors,
                    rotateDegrees: rotation,
                    onTap: () {
                      ref.read(currentTabIndexProvider.notifier).state =
                          1; // Collection
                    },
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}
