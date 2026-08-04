import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/cabinet_colors.dart';
import '../../core/theme/cabinet_theme.dart';
import '../../shared/widgets/cabinet_widgets.dart';
import '../../features/words/data/models/word.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../features/words/presentation/screens/word_form_screen.dart';
import '../../features/words/presentation/screens/word_list_screen.dart';
import '../../features/review/presentation/screens/review_screen.dart';
import '../../home/home_screen.dart';

final streakDataProvider = FutureProvider<List<int>>((ref) async {
  final repo = ref.watch(reviewRepositoryProvider);
  return repo.getStreakGridData(days: 182);
});

final dashboardStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final repo = ref.watch(reviewRepositoryProvider);
  final stats = await repo.getReviewStats();
  final currentStreak = await repo.getCurrentStreakDays();
  return {
    'totalReviews': stats['totalReviews'] as int? ?? 0,
    'currentStreak': currentStreak,
  };
});

class HomeDashboardScreen extends ConsumerStatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  ConsumerState<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  bool _isFlipped = false;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    if (_isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(cabinetThemeModeProvider);
    final colors = CabinetColors.fromMode(themeMode);
    final theme = CabinetTheme(colors);

    final wordsAsync = ref.watch(wordListProvider);
    final words = wordsAsync.value ?? [];

    final streakAsync = ref.watch(streakDataProvider);
    final streakData = streakAsync.value ?? List<int>.filled(182, 0);

    final statsAsync = ref.watch(dashboardStatsProvider);
    final statsData = statsAsync.value ?? {'totalReviews': 0, 'currentStreak': 0};
    final streakDays = statsData['currentStreak'] ?? 0;
    final totalReviews = statsData['totalReviews'] ?? 0;

    final now = DateTime.now();
    // 30분 단위 시드 (30분마다 자동 단어 변경)
    final slot30Min = (now.millisecondsSinceEpoch / (1000 * 60 * 30)).floor();
    final Word? wordOfDay = words.isNotEmpty ? words[slot30Min % words.length] : null;
    final totalCount = words.length;
    final masteredCount = words.where((w) => w.difficulty <= 2).length;
    final plantLevel = math.min(5, (totalCount / 10).floor());

    return CabinetPaperScaffold(
      colors: colors,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Section Head
            CabinetSectionHead(
              eyebrow: 'Section 01 · Dashboard',
              title: 'Linguistic Cabinet',
              subtitle: 'Collected Moments & Archive',
              colors: colors,
            ),
            const SizedBox(height: 24),

            // Responsive Layout: 2 Columns on Wide Screens, 1 Column on Mobile
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 800;
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column (60%)
                      Expanded(
                        flex: 6,
                        child: Column(
                          children: [
                            _buildWordOfTheDayCard(context, wordOfDay, colors, theme),
                            const SizedBox(height: 20),
                            CabinetStreakGrid(streakLevels: streakData, colors: colors),
                            const SizedBox(height: 20),
                            _buildRecentlyCollectedStrip(context, words, colors, theme),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      // Right Column (40%)
                      Expanded(
                        flex: 4,
                        child: Column(
                          children: [
                            CabinetWordGarden(
                              plantLevel: plantLevel,
                              colors: colors,
                              totalCount: totalCount,
                              masteredCount: masteredCount,
                            ),
                            const SizedBox(height: 20),
                            _buildLedgerSummary(totalCount, masteredCount, streakDays, totalReviews, colors, theme),
                            const SizedBox(height: 20),
                            _buildQuickActions(context, colors),
                          ],
                        ),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildWordOfTheDayCard(context, wordOfDay, colors, theme),
                      const SizedBox(height: 20),
                      CabinetWordGarden(
                        plantLevel: plantLevel,
                        colors: colors,
                        totalCount: totalCount,
                      ),
                      const SizedBox(height: 20),
                      CabinetStreakGrid(streakLevels: streakData, colors: colors),
                      const SizedBox(height: 20),
                      _buildLedgerSummary(totalCount, masteredCount, streakDays, totalReviews, colors, theme),
                      const SizedBox(height: 20),
                      _buildRecentlyCollectedStrip(context, words, colors, theme),
                      const SizedBox(height: 20),
                      _buildQuickActions(context, colors),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 1. Word of the Day Card with 3D Flip & Masking Tapes
  Widget _buildWordOfTheDayCard(
    BuildContext context,
    Word? word,
    CabinetColors colors,
    CabinetTheme theme,
  ) {
    if (word == null) {
      return CabinetPaperCard(
        colors: colors,
        child: SizedBox(
          height: 220,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'No words collected yet.\nTap or click below to start your cabinet!',
                  textAlign: TextAlign.center,
                  style: theme.handNote.copyWith(fontSize: 18, color: colors.ink3),
                ),
                const SizedBox(height: 14),
                CabinetBrutalButton(
                  text: '단어 추가하기 (Add Word)',
                  icon: Icons.add,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const WordFormScreen()),
                    ).then((_) {
                      ref.invalidate(wordListProvider);
                      ref.invalidate(filteredWordsProvider);
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Card Body with 3D Flip
        GestureDetector(
          onTap: _toggleFlip,
          child: AnimatedBuilder(
            animation: _flipController,
            builder: (context, child) {
              final angle = _flipController.value * math.pi;
              final isFront = angle < math.pi / 2;

              return Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(angle),
                alignment: Alignment.center,
                child: isFront
                    ? _buildWordOfDayFront(word, colors, theme)
                    : Transform(
                        transform: Matrix4.identity()..rotateY(math.pi),
                        alignment: Alignment.center,
                        child: _buildWordOfDayBack(word, colors, theme),
                      ),
              );
            },
          ),
        ),

        // Tape on top left
        Positioned(
          top: -8,
          left: 16,
          child: CabinetTape(color: colors.tapeYellow, rotateDegrees: -8),
        ),
        // Tape on top right
        Positioned(
          top: -6,
          right: 24,
          child: CabinetTape(color: colors.tapePink, rotateDegrees: 5),
        ),
      ],
    );
  }

  Widget _buildWordOfDayFront(Word word, CabinetColors colors, CabinetTheme theme) {
    return CabinetPaperCard(
      colors: colors,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('CAB · TODAY\'S WORD', style: theme.labelMono),
              Text('TAP TO FLIP ↺', style: theme.labelMono.copyWith(color: colors.accent)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            word.english,
            style: theme.wordHuge.copyWith(color: colors.ink),
          ),
          if (word.pronunciation != null && word.pronunciation!.isNotEmpty) ...[
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  word.pronunciation!,
                  style: theme.labelMono.copyWith(color: colors.ink3, fontSize: 13, height: 1.4),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            '뜻을 떠올려보세요 →',
            style: theme.handNote.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '#0001 · ${word.tags.isNotEmpty ? word.tags.first.toUpperCase() : 'GENERAL'}',
                style: theme.catalogNo,
              ),
              CabinetBrutalButton(
                text: '오늘 복습',
                icon: Icons.play_arrow,
                onPressed: () {
                  ref.read(currentTabIndexProvider.notifier).state = 2; // Move to Review
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWordOfDayBack(Word word, CabinetColors colors, CabinetTheme theme) {
    return CabinetPaperCard(
      colors: colors,
      padding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 380),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('MEANING & CONTEXT', style: theme.labelMono),
                  Text('TAP TO FLIP ↺', style: theme.labelMono.copyWith(color: colors.accent)),
                ],
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.only(right: 12, top: 2, bottom: 2),
                child: Text(
                  word.korean,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.meaningSerif.copyWith(
                    fontSize: 22,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (word.exampleSentence != null && word.exampleSentence!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  '"${word.exampleSentence}"',
                  style: theme.meaningSerif.copyWith(fontSize: 15, color: colors.ink2),
                ),
              ],
              if (word.memo != null && word.memo!.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.paper3,
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(color: colors.inkLineStrong, width: 0.8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Moment Note:',
                        style: theme.labelMono.copyWith(fontSize: 10, color: colors.accent, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      MarkdownBody(
                        data: word.memo!,
                        styleSheet: theme.buildMarkdownStyle(fontSize: 17, textColor: colors.ink),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: CabinetBrutalButton(
                  text: '복습 완료',
                  icon: Icons.check,
                  onPressed: _toggleFlip,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 3. Recently Collected Scrap Strip
  Widget _buildRecentlyCollectedStrip(
    BuildContext context,
    List<Word> words,
    CabinetColors colors,
    CabinetTheme theme,
  ) {
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
                    catalogNo: 'CAB · #${(index + 1).toString().padLeft(4, '0')}',
                    english: w.english,
                    ipa: w.pronunciation,
                    korean: w.korean,
                    tag: w.tags.isNotEmpty ? w.tags.first : 'GENERAL',
                    colors: colors,
                    rotateDegrees: rotation,
                    onTap: () {
                      ref.read(currentTabIndexProvider.notifier).state = 1; // Collection
                    },
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  /// 4. Ledger Summary
  Widget _buildLedgerSummary(
    int total,
    int mastered,
    int streakDays,
    int totalReviews,
    CabinetColors colors,
    CabinetTheme theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('LEDGER SUMMARY', style: theme.labelMono),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.6,
          children: [
            _buildStatItem('Collected', total.toString(), colors.paper2, colors, theme),
            _buildStatItem('Mastered', mastered.toString(), colors.paper3, colors, theme, isAccent: true),
            _buildStatItem('Streak', '$streakDays ${streakDays == 1 ? 'Day' : 'Days'}', colors.paper2, colors, theme),
            _buildStatItem('Reviews', '$totalReviews', colors.paper2, colors, theme),
          ],
        ),
      ],
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    Color bg,
    CabinetColors colors,
    CabinetTheme theme, {
    bool isAccent = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: isAccent ? colors.accent : colors.inkLineStrong,
          width: isAccent ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label.toUpperCase(), style: theme.labelMono.copyWith(fontSize: 9)),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.displaySerif.copyWith(
              fontSize: 22,
              color: isAccent ? colors.accent : colors.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// 5. Quick Actions
  Widget _buildQuickActions(BuildContext context, CabinetColors colors) {
    return Column(
      children: [
        CabinetBrutalButton(
          text: '오늘의 복습 시작',
          icon: Icons.autorenew,
          fullWidth: true,
          onPressed: () {
            ref.read(currentTabIndexProvider.notifier).state = 2; // Review
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: CabinetBrutalButton(
                text: '퀴즈 풀기',
                icon: Icons.help_outline,
                bg: colors.paper2,
                textColor: colors.ink,
                onPressed: () {
                  ref.read(currentTabIndexProvider.notifier).state = 3; // Quiz
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: CabinetBrutalButton(
                text: '매칭 게임',
                icon: Icons.grid_view,
                bg: colors.paper2,
                textColor: colors.ink,
                onPressed: () {
                  ref.read(currentTabIndexProvider.notifier).state = 4; // Match
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
