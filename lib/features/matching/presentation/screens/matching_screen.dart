import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../words/data/models/word.dart';
import '../../../words/presentation/screens/word_list_screen.dart';
import '../../../../core/theme/cabinet_colors.dart';
import '../../../../core/theme/cabinet_theme.dart';
import '../../../../shared/widgets/cabinet_widgets.dart';
import 'word_matching_screen.dart';
import 'grid_matching_screen.dart';

final matchingWordsProvider = FutureProvider<List<Word>>((ref) async {
  final repo = ref.watch(wordRepositoryProvider);
  return repo.getAllWords();
});

class MatchingScreen extends ConsumerWidget {
  const MatchingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(cabinetThemeModeProvider);
    final colors = CabinetColors.fromMode(themeMode);
    final theme = CabinetTheme(colors);

    final wordsAsync = ref.watch(matchingWordsProvider);

    return CabinetPaperScaffold(
      colors: colors,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CabinetSectionHead(
              eyebrow: 'Section 05 · Matching Room',
              title: 'Pair & Memory Games',
              subtitle: '2 Match Modes Available',
              colors: colors,
            ),
            const SizedBox(height: 24),

            wordsAsync.when(
              data: (words) {
                if (words.length < 4) {
                  return _buildEmptyState(colors, theme);
                }
                return _buildMatchingGrid(context, words, colors, theme);
              },
              loading: () => Center(child: CircularProgressIndicator(color: colors.accent)),
              error: (err, stack) => Center(child: Text('오류: $err', style: theme.bodySans)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(CabinetColors colors, CabinetTheme theme) {
    return CabinetPaperCard(
      colors: colors,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            CabinetStamp(text: 'MINIMUM 4 WORDS REQUIRED', color: colors.accent),
            const SizedBox(height: 16),
            Text(
              '매칭 게임을 시작하려면 최소 4개 이상의 단어가 필요합니다.',
              style: theme.wordTitle.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              '컬렉션에 새 단어를 먼저 추가해 보세요!',
              style: theme.handNote.copyWith(fontSize: 18, color: colors.ink3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchingGrid(
    BuildContext context,
    List<Word> words,
    CabinetColors colors,
    CabinetTheme theme,
  ) {
    return Column(
      children: [
        // Card 1: Line Match
        Stack(
          clipBehavior: Clip.none,
          children: [
            CabinetPaperCard(
              colors: colors,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('MATCH · 01', style: theme.catalogNo),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: colors.paper3, borderRadius: BorderRadius.circular(99)),
                        child: Text('6 PAIRS LINE', style: theme.labelMono.copyWith(fontSize: 8)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('단어-뜻 잇기 (Line Match)', style: theme.wordTitle.copyWith(fontSize: 22)),
                  Text('Line Connection Pair Game', style: theme.labelMono.copyWith(color: colors.ink3, fontSize: 10)),
                  const SizedBox(height: 8),
                  Text(
                    '좌측 단어와 우측 뜻을 하나씩 클릭하여 일치하는 페어를 찾아보세요.',
                    style: theme.handNote.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: CabinetBrutalButton(
                      text: '게임 시작 (START)',
                      icon: Icons.play_arrow,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => WordMatchingScreen(words: words)),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: -6,
              left: 18,
              child: CabinetTape(color: colors.tapeYellow, rotateDegrees: -4),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Card 2: Grid Memory Match
        Stack(
          clipBehavior: Clip.none,
          children: [
            CabinetPaperCard(
              colors: colors,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('MATCH · 02', style: theme.catalogNo),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: colors.paper3, borderRadius: BorderRadius.circular(99)),
                        child: Text('12 CARDS GRID', style: theme.labelMono.copyWith(fontSize: 8)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('그리드 메모리 (Grid Memory)', style: theme.wordTitle.copyWith(fontSize: 22)),
                  Text('3D Flip Memory Card Game', style: theme.labelMono.copyWith(color: colors.ink3, fontSize: 10)),
                  const SizedBox(height: 8),
                  Text(
                    '4x3 그리드 카드를 뒤집어 짝이 맞는 단어와 뜻을 기억해 맞춰보세요.',
                    style: theme.handNote.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: CabinetBrutalButton(
                      text: '게임 시작 (START)',
                      icon: Icons.grid_view,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => GridMatchingScreen(words: words)),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: -6,
              left: 18,
              child: CabinetTape(color: colors.tapePink, rotateDegrees: 5),
            ),
          ],
        ),
      ],
    );
  }
}
