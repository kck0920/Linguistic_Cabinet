import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/cabinet_colors.dart';
import '../core/theme/cabinet_theme.dart';
import '../shared/widgets/cabinet_widgets.dart';
import '../features/words/presentation/screens/word_list_screen.dart';
import '../features/review/presentation/screens/review_screen.dart';
import '../features/achievements/data/achievement_evaluator.dart';
import '../features/achievements/data/achievement_service.dart';
import '../features/achievements/data/anniversary_service.dart';
import '../features/achievements/presentation/master_garden_certificate_screen.dart';
import '../features/achievements/presentation/master_garden_guide_screen.dart';
import 'home_screen.dart';
import 'widgets/dashboard_word_of_day_card.dart';
import 'widgets/dashboard_recent_strip.dart';
import 'widgets/dashboard_ledger_summary.dart';
import 'widgets/dashboard_quick_actions.dart';
import 'widgets/dashboard_anniversary_banner.dart';
import 'widgets/dashboard_achievements_entry.dart';

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

/// 홈 대시보드 — 데이터 수집·업적 자가치유·컨페티 축하를 담당하는 셸.
/// 카드/배너 등 UI 블록은 `widgets/dashboard_*.dart`에 위임한다.
class HomeDashboardScreen extends ConsumerStatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  ConsumerState<HomeDashboardScreen> createState() =>
      _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen> {
  bool _showConfetti = false;
  int _confettiSeed = 0;
  int _celebratedLevel = 0;

  @override
  void initState() {
    super.initState();
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
    final wordOfDay =
        words.isNotEmpty ? words[slot30Min % words.length] : null;
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
                  DashboardAnniversaryBanner(
                    onCelebrate: () =>
                        _handleGardenLevelUp(CabinetWordGarden.maxGardenLevel),
                  ),
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
                                DashboardWordOfDayCard(word: wordOfDay),
                                const SizedBox(height: 20),
                                CabinetStreakGrid(
                                  streakLevels: streakData,
                                  colors: colors,
                                ),
                                const SizedBox(height: 20),
                                DashboardRecentStrip(words: words),
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
                                DashboardAchievementsEntry(
                                  colors: colors,
                                  theme: theme,
                                ),
                                const SizedBox(height: 20),
                                DashboardLedgerSummary(
                                  total: totalCount,
                                  mastered: masteredCount,
                                  streakDays: streakDays,
                                  totalReviews: totalReviews,
                                  colors: colors,
                                  theme: theme,
                                ),
                                const SizedBox(height: 20),
                                const DashboardQuickActions(),
                              ],
                            ),
                          ),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          DashboardWordOfDayCard(word: wordOfDay),
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
                          DashboardAchievementsEntry(
                            colors: colors,
                            theme: theme,
                          ),
                          const SizedBox(height: 20),
                          CabinetStreakGrid(
                            streakLevels: streakData,
                            colors: colors,
                          ),
                          const SizedBox(height: 20),
                          DashboardLedgerSummary(
                            total: totalCount,
                            mastered: masteredCount,
                            streakDays: streakDays,
                            totalReviews: totalReviews,
                            colors: colors,
                            theme: theme,
                          ),
                          const SizedBox(height: 20),
                          DashboardRecentStrip(words: words),
                          const SizedBox(height: 20),
                          const DashboardQuickActions(),
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
}
