import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/cabinet_colors.dart';
import '../../core/theme/cabinet_theme.dart';
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

    // 전체 단어의 등록 순서(오래된 순) 매핑을 위한 리스트
    final chronological = List<Word>.from(words)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // 최근 등록일(createdAt) 기준 내림차순 정렬하여 최신 4장 추출
    final recent = List<Word>.from(words)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
                final w = displayWords[index];
                final rotation = (index % 2 == 0) ? 1.2 : -1.4;
                final catIndex = chronological.indexOf(w);
                final catalogNo = catIndex >= 0
                    ? 'CAB · #${(catIndex + 1).toString().padLeft(4, '0')}'
                    : 'CAB · #${(index + 1).toString().padLeft(4, '0')}';

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
