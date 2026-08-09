import 'dart:async';
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
import '../../features/achievements/data/achievement_evaluator.dart';
import '../../features/achievements/data/achievement_service.dart';
import '../../features/achievements/data/anniversary_service.dart';
import '../../features/achievements/presentation/achievement_collection_screen.dart';
import '../../features/achievements/presentation/master_garden_certificate_screen.dart';
import '../../features/achievements/presentation/master_garden_guide_screen.dart';
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
  ConsumerState<HomeDashboardScreen> createState() =>
      _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  bool _isFlipped = false;
  bool _showConfetti = false;
  int _confettiSeed = 0;
  int _celebratedLevel = 0;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    // 자기치유: 최초 로드 시 이미 레벨 20이면 배지를 수여한다.
    // (가져오기/복원으로 2,000단어 이상이 되어도 배지를 받을 수 있게)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final totalCount = ref.read(wordListProvider).valueOrNull?.length ?? 0;
      if (totalCount >= CabinetWordGarden.maxGardenWords) {
        _awardMasterGardenBadge();
      }
      // 스트릭/월간/수집 업적도 자가치유로 수여한다.
      _evaluateAchievements();
    });
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

  /// 정원 레벨업 알림: 화면 전체 컨페티 축하를 트리거한다.
  /// 레벨 20(만개) 달성 시 기념 배지를 영구 저장한다.
  void _handleGardenLevelUp(int level) {
    setState(() {
      _confettiSeed++;
      _celebratedLevel = level;
      _showConfetti = true;
    });
    if (level >= CabinetWordGarden.maxGardenLevel) {
      _awardMasterGardenBadge();
    }
  }

  /// 스트릭/월간/수집 업적을 평가해 잔여 업적을 자동 수여한다.
  /// (공용 [AchievementEvaluator]가 수여·프로바이더 갱신·토스트 방출을 담당)
  Future<void> _evaluateAchievements() async {
    await ref.read(achievementEvaluatorProvider).evaluateNow();
  }

  /// 마스터 정원 배지 수여: 업적 서비스의 awardIfNotEarned로 영구 저장.
  /// (이미 수여됐으면 스킵 — 중복 저장 방지 로직은 서비스에 위임)
  Future<void> _awardMasterGardenBadge() async {
    try {
      final repo = ref.read(reviewRepositoryProvider);
      final service = AchievementService(repo);
      final awarded = await service.awardIfNotEarned(
        AnniversaryService.badgeKey,
        DateTime.now(),
      );
      if (awarded) ref.invalidate(masterGardenBadgeProvider);
    } catch (_) {
      // 저장 실패는 치명적이지 않으므로 무시 (다음 기회에 재수여)
    }
  }

  @override
  Widget build(BuildContext context) {
    // 홈 탭으로 돌아올 때마다 업적을 재평가해 새 해금을 토스트로 알린다.
    // (복습/퀴즈 직후 스트릭·월간 업적이 해금되는 경우 실시간 반영)
    // 퀴즈/매칭 등에서 쌓인 복습 로그를 반영해 통계·스트릭도 함께 최신화한다.
    ref.listen<int>(currentTabIndexProvider, (prev, next) {
      if (next == 0 && prev != 0) {
        ref.invalidate(dashboardStatsProvider);
        ref.invalidate(streakDataProvider);
        ref.invalidate(masteredCountProvider);
        _evaluateAchievements();
        // 복습/퀴즈/매칭에서 변한 학습 상태를 홈 화면 위젯에도 반영.
        unawaited(ref.read(homeWidgetServiceProvider).refreshWidgetData());
      }
    });

    final themeMode = ref.watch(cabinetThemeModeProvider);
    final colors = CabinetColors.fromMode(themeMode);
    final theme = CabinetTheme(colors);

    final wordsAsync = ref.watch(wordListProvider);
    final words = wordsAsync.value ?? [];

    final streakAsync = ref.watch(streakDataProvider);
    final streakData = streakAsync.value ?? List<int>.filled(182, 0);

    final statsAsync = ref.watch(dashboardStatsProvider);
    final statsData =
        statsAsync.value ?? {'totalReviews': 0, 'currentStreak': 0};
    final streakDays = statsData['currentStreak'] ?? 0;
    final totalReviews = statsData['totalReviews'] ?? 0;

    final now = DateTime.now();
    // 30분 단위 시드 (30분마다 자동 단어 변경)
    final slot30Min = (now.millisecondsSinceEpoch / (1000 * 60 * 30)).floor();
    final Word? wordOfDay = words.isNotEmpty
        ? words[slot30Min % words.length]
        : null;
    final totalCount = words.length;
    // 숙달 수는 공용 프로바이더(getMasteredCount)의 단일 진실 원천을 사용한다.
    final masteredAsync = ref.watch(masteredCountProvider);
    final masteredCount = masteredAsync.value ?? 0;
    final badgeAsync = ref.watch(masterGardenBadgeProvider);
    final badgeDate = badgeAsync.valueOrNull;

    // 마스터 정원 기념일: 오늘이 달성 기념일이면 축하 배너를 띄운다.
    final anniversaryAsync = ref.watch(anniversaryTodayProvider);
    final isAnniversary = anniversaryAsync.valueOrNull ?? false;

    return Stack(
      children: [
        CabinetPaperScaffold(
          colors: colors,
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 마스터 정원 기념일 축하 배너 (달성 기념일 당일에만 표시)
                if (isAnniversary) ...[
                  _buildAnniversaryBanner(colors, theme),
                  const SizedBox(height: 20),
                ],
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
                                _buildWordOfTheDayCard(
                                  context,
                                  wordOfDay,
                                  colors,
                                  theme,
                                ),
                                const SizedBox(height: 20),
                                CabinetStreakGrid(
                                  streakLevels: streakData,
                                  colors: colors,
                                ),
                                const SizedBox(height: 20),
                                _buildRecentlyCollectedStrip(
                                  context,
                                  words,
                                  colors,
                                  theme,
                                ),
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
                                  colors: colors,
                                  totalCount: totalCount,
                                  masteredCount: masteredCount,
                                  onLevelUp: _handleGardenLevelUp,
                                ),
                                const SizedBox(height: 14),
                                CabinetBadgeCard(
                                  achievedDate: badgeDate,
                                  colors: colors,
                                  currentCount: totalCount,
                                  thresholdCount:
                                      CabinetWordGarden.maxGardenWords,
                                  onTap: () => _openBadge(badgeDate),
                                ),
                                const SizedBox(height: 8),
                                _buildAchievementsEntry(colors, theme),
                                const SizedBox(height: 20),
                                _buildLedgerSummary(
                                  totalCount,
                                  masteredCount,
                                  streakDays,
                                  totalReviews,
                                  colors,
                                  theme,
                                ),
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
                          _buildWordOfTheDayCard(
                            context,
                            wordOfDay,
                            colors,
                            theme,
                          ),
                          const SizedBox(height: 20),
                          CabinetWordGarden(
                            colors: colors,
                            totalCount: totalCount,
                            onLevelUp: _handleGardenLevelUp,
                          ),
                          const SizedBox(height: 14),
                          CabinetBadgeCard(
                            achievedDate: badgeDate,
                            colors: colors,
                            currentCount: totalCount,
                            thresholdCount: CabinetWordGarden.maxGardenWords,
                            onTap: () => _openBadge(badgeDate),
                          ),
                          const SizedBox(height: 8),
                          _buildAchievementsEntry(colors, theme),
                          const SizedBox(height: 20),
                          CabinetStreakGrid(
                            streakLevels: streakData,
                            colors: colors,
                          ),
                          const SizedBox(height: 20),
                          _buildLedgerSummary(
                            totalCount,
                            masteredCount,
                            streakDays,
                            totalReviews,
                            colors,
                            theme,
                          ),
                          const SizedBox(height: 20),
                          _buildRecentlyCollectedStrip(
                            context,
                            words,
                            colors,
                            theme,
                          ),
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
        ),
        if (_showConfetti)
          Positioned.fill(
            child: IgnorePointer(
              child: CabinetConfettiOverlay(
                key: ValueKey(_confettiSeed),
                colors: colors,
                big: CabinetWordGarden.isMilestoneLevel(_celebratedLevel),
                // 만개(레벨 20): 화면 전체가 잠깐 반짝이는 플래시 효과
                flash: _celebratedLevel >= CabinetWordGarden.maxGardenLevel,
                onFinished: () => setState(() => _showConfetti = false),
              ),
            ),
          ),
      ],
    );
  }

  /// 마스터 정원 배지 탭: 해금 상태면 수료증, 미해금 상태면 해금 조건 안내 화면.
  void _openBadge(String? achievedDate) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => achievedDate != null
            ? const MasterGardenCertificateScreen()
            : const MasterGardenGuideScreen(),
      ),
    );
  }

  /// 업적 컬렉션 진입 버튼 (배지 카드 바로 아래).
  Widget _buildAchievementsEntry(CabinetColors colors, CabinetTheme theme) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AchievementCollectionScreen(),
          ),
        );
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: colors.paper3,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: colors.inkLineStrong, width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('MERITS · 업적 컬렉션', style: theme.labelMono),
              Icon(Icons.arrow_forward, size: 14, color: colors.accent),
            ],
          ),
        ),
      ),
    );
  }

  /// 기념일 축하 배너: 오늘이 마스터 정원 달성 기념일이면 표시.
  /// 배너를 탭하면 만개 축하 연출(컨페티+플래시)이 재생된다.
  Widget _buildAnniversaryBanner(CabinetColors colors, CabinetTheme theme) {
    return GestureDetector(
      onTap: _celebrateAnniversary,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          decoration: BoxDecoration(
            color: colors.tapeYellow.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: colors.accent, width: 1.5),
          ),
          child: Row(
            children: [
              const Text('🎉', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MASTER GARDENER ANNIVERSARY',
                      style: theme.labelMono.copyWith(
                        color: colors.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '1년 전 오늘, 2,000단어를 모아 정원을 완성했어요.\n탭하면 축하 연출이 재생됩니다.',
                      style: theme.bodySans.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '닫기',
                icon: Icon(Icons.close, size: 18, color: colors.ink3),
                onPressed: _dismissAnniversary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 기념일 축하 재생: 올해 축하 완료로 기록 후 만개 축하(컨페티+플래시) 실행.
  Future<void> _celebrateAnniversary() async {
    try {
      final service = ref.read(anniversaryServiceProvider);
      await service.markAnniversaryCelebrated();
      ref.invalidate(anniversaryTodayProvider);
    } catch (_) {
      // 기록 실패는 치명적이지 않음 (다음 실행에 재시도)
    }
    // 만개 스페셜(황금 고리+꽃가루+플래시) 연출을 재생한다.
    _handleGardenLevelUp(CabinetWordGarden.maxGardenLevel);
  }

  /// 기념일 배너 닫기: 올해 축하 완료로 기록.
  Future<void> _dismissAnniversary() async {
    try {
      final service = ref.read(anniversaryServiceProvider);
      await service.markAnniversaryCelebrated();
      ref.invalidate(anniversaryTodayProvider);
    } catch (_) {}
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
                  style: theme.handNote.copyWith(
                    fontSize: 18,
                    color: colors.ink3,
                  ),
                ),
                const SizedBox(height: 14),
                CabinetBrutalButton(
                  text: '단어 추가하기 (Add Word)',
                  icon: Icons.add,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WordFormScreen(),
                      ),
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

  Widget _buildWordOfDayFront(
    Word word,
    CabinetColors colors,
    CabinetTheme theme,
  ) {
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
              Text(
                'TAP TO FLIP ↺',
                style: theme.labelMono.copyWith(color: colors.accent),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(word.english, style: theme.wordHuge.copyWith(color: colors.ink)),
          if (word.pronunciation != null && word.pronunciation!.isNotEmpty) ...[
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  word.pronunciation!,
                  style: theme.labelMono.copyWith(
                    color: colors.ink3,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text('뜻을 떠올려보세요 →', style: theme.handNote.copyWith(fontSize: 20)),
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
                  ref.read(currentTabIndexProvider.notifier).state =
                      2; // Move to Review
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWordOfDayBack(
    Word word,
    CabinetColors colors,
    CabinetTheme theme,
  ) {
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
                  Text(
                    'TAP TO FLIP ↺',
                    style: theme.labelMono.copyWith(color: colors.accent),
                  ),
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
              if (word.exampleSentence != null &&
                  word.exampleSentence!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  '"${word.exampleSentence}"',
                  style: theme.meaningSerif.copyWith(
                    fontSize: 15,
                    color: colors.ink2,
                  ),
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
                        style: theme.labelMono.copyWith(
                          fontSize: 10,
                          color: colors.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      MarkdownBody(
                        data: word.memo!,
                        styleSheet: theme.buildMarkdownStyle(
                          fontSize: 17,
                          textColor: colors.ink,
                        ),
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

  /// 4. Ledger Summary
  Widget _buildLedgerSummary(
    int total,
    int mastered,
    int streakDays,
    int totalReviews,
    CabinetColors colors,
    CabinetTheme theme,
  ) {
    // 숙달 진행률: 전체 수집 단어 중 숙달(난이도 ≤ 2) 비율
    final masteredPct = total > 0 ? (mastered / total * 100).round() : 0;
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
            _buildStatItem(
              'Collected',
              total.toString(),
              colors.paper2,
              colors,
              theme,
            ),
            _buildStatItem(
              'Mastered',
              total > 0
                  ? '${AchievementService.formatCount(mastered)} / ${AchievementService.formatCount(total)}'
                  : '0',
              colors.paper3,
              colors,
              theme,
              isAccent: true,
              subtitle: total > 0 ? '$masteredPct% 숙달' : null,
            ),
            _buildStatItem(
              'Streak',
              '$streakDays ${streakDays == 1 ? 'Day' : 'Days'}',
              colors.paper2,
              colors,
              theme,
            ),
            _buildStatItem(
              'Reviews',
              '$totalReviews',
              colors.paper2,
              colors,
              theme,
            ),
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
    String? subtitle,
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
          Text(
            label.toUpperCase(),
            style: theme.labelMono.copyWith(fontSize: 9),
          ),
          const SizedBox(height: 4),
          // 값(예: '3 / 5', '1,200 / 2,000')이 좁은 타일에서 넘치지 않도록 스케일다운
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: theme.displaySerif.copyWith(
                fontSize: 22,
                color: isAccent ? colors.accent : colors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                subtitle,
                maxLines: 1,
                style: theme.labelMono.copyWith(
                  fontSize: 8,
                  color: isAccent ? colors.accent : colors.ink3,
                ),
              ),
            ),
          ],
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


