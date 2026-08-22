import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/cabinet_colors.dart';
import '../../../../core/theme/cabinet_theme.dart';
import '../../../../core/utils/format_count.dart';
import '../../../../shared/widgets/cabinet_widgets.dart';
import '../../../words/presentation/screens/word_list_screen.dart';
import '../../../review/presentation/screens/review_screen.dart';
import '../../../../dev/garden_preview_screen.dart';

/// 설정 화면 4번 탭 — 학습 통계
class SettingsStatsTab extends ConsumerWidget {
  const SettingsStatsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(cabinetThemeModeProvider);
    final colors = CabinetColors.fromMode(themeMode);
    final theme = CabinetTheme(colors);

    final wordsAsync = ref.watch(wordListProvider);
    final words = wordsAsync.value ?? [];
    final totalWords = words.length;
    // 숙달 수는 공용 프로바이더(getMasteredCount)의 단일 진실 원천을 사용한다.
    final masteredAsync = ref.watch(masteredCountProvider);
    final mastered = masteredAsync.value ?? 0;
    // 숙달 진행률: 전체 수집 단어 중 숙달(난이도 ≤ 2) 비율 (대시보드 타일과 동일 형식)
    final masteredPct = totalWords > 0 ? (mastered / totalWords * 100).round() : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('LEARNING STATISTICS', style: theme.labelMono),
        const SizedBox(height: 14),
        CabinetPaperCard(
          colors: colors,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text('TOTAL WORDS', style: theme.labelMono),
                      Text('$totalWords', style: theme.displaySerif.copyWith(fontSize: 32)),
                    ],
                  ),
                  Column(
                    children: [
                      Text('MASTERED', style: theme.labelMono),
                      Text(
                        totalWords > 0
                            ? '${formatCount(mastered)} / ${formatCount(totalWords)}'
                            : '0',
                        style: theme.displaySerif.copyWith(fontSize: 32, color: colors.accent3),
                      ),
                      if (totalWords > 0)
                        Text(
                          '$masteredPct% 숙달',
                          style: theme.labelMono.copyWith(fontSize: 9, color: colors.accent3),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Monthly Progress', style: theme.wordTitle.copyWith(fontSize: 18)),
              const SizedBox(height: 10),
              SizedBox(
                height: 100,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(20, (i) {
                    final h = (i * 7 + 15) % 80 + 10.0;
                    return Container(
                      width: 8,
                      height: h,
                      decoration: BoxDecoration(
                        color: i > 15 ? colors.accent : colors.inkLineStrong,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
        if (kGardenPreviewEnabled) ...[
          const SizedBox(height: 24),
          Text('DEV TOOLS', style: theme.labelMono),
          const SizedBox(height: 10),
          CabinetPaperCard(
            colors: colors,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('단어 정원 미리보기', style: theme.wordTitle.copyWith(fontSize: 16)),
                const SizedBox(height: 6),
                Text(
                  '레벨 0~20 화분/식물 모습을 개발용으로 확인합니다.',
                  style: theme.bodySans.copyWith(color: colors.ink3),
                ),
                const SizedBox(height: 12),
                CabinetBrutalButton(
                  text: '정원 미리보기 열기',
                  icon: Icons.grass,
                  fullWidth: true,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const GardenPreviewScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
