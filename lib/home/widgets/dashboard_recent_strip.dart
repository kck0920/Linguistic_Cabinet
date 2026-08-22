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
    final recent = words.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('RECENTLY COLLECTED', style: theme.labelMono),
        const SizedBox(height: 10),
        if (recent.isEmpty)
          Text('No recent cards.', style: theme.bodySans)
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(recent.length, (index) {
                final w = recent[index];
                final rotation = (index % 2 == 0) ? 1.2 : -1.4;
                return Container(
                  width: 170,
                  margin: const EdgeInsets.only(right: 14),
                  child: CabinetCatalogCard(
                    catalogNo:
                        'CAB · #${(index + 1).toString().padLeft(4, '0')}',
                    english: w.english,
                    ipa: w.pronunciation,
                    korean: w.korean,
                    tag: w.tags.isNotEmpty ? w.tags.first : 'GENERAL',
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
