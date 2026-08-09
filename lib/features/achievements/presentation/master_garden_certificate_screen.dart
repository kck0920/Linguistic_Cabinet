import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/cabinet_colors.dart';
import '../../../core/theme/cabinet_theme.dart';
import '../../../shared/widgets/cabinet_widgets.dart';
import '../../review/presentation/screens/review_screen.dart';
import '../../words/presentation/screens/word_list_screen.dart';
import '../data/achievement_service.dart';
import 'achievement_collection_screen.dart';

/// 수료증 화면용 통계 (복습 수·연속 학습일).
final certificateStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final repo = ref.watch(reviewRepositoryProvider);
  final stats = await repo.getReviewStats();
  final currentStreak = await repo.getCurrentStreakDays();
  return {
    'totalReviews': stats['totalReviews'] as int? ?? 0,
    'currentStreak': currentStreak,
  };
});

/// 마스터 정원 수료증: 레벨 20(2,000단어) 달성 기념 공식 문서.
/// 배지 달성 날짜·통계·도장·서명을 종이 질감 위에 표시한다.
class MasterGardenCertificateScreen extends ConsumerWidget {
  const MasterGardenCertificateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(cabinetThemeModeProvider);
    final colors = CabinetColors.fromMode(themeMode);
    final theme = CabinetTheme(colors);

    final badgeAsync = ref.watch(masterGardenBadgeProvider);
    final wordsAsync = ref.watch(wordListProvider);
    final statsAsync = ref.watch(certificateStatsProvider);

    final achievedDate = badgeAsync.valueOrNull;
    final words = wordsAsync.value ?? [];
    final stats =
        statsAsync.value ?? {'totalReviews': 0, 'currentStreak': 0};

    final totalWords = words.length;
    // 숙달 수는 공용 프로바이더(getMasteredCount)의 단일 진실 원천을 사용한다.
    final masteredAsync = ref.watch(masteredCountProvider);
    final mastered = masteredAsync.value ?? 0;
    final streak = stats['currentStreak'] ?? 0;
    final reviews = stats['totalReviews'] ?? 0;

    return CabinetPaperScaffold(
      colors: colors,
      appBar: AppBar(
        backgroundColor: colors.paper2,
        foregroundColor: colors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'CERTIFICATE',
          style: theme.labelMono.copyWith(fontSize: 12, letterSpacing: 2),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: _buildCertificate(
              context,
              achievedDate: achievedDate,
              totalWords: totalWords,
              mastered: mastered,
              streak: streak,
              reviews: reviews,
              colors: colors,
              theme: theme,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCertificate(
    BuildContext context, {
    required String? achievedDate,
    required int totalWords,
    required int mastered,
    required int streak,
    required int reviews,
    required CabinetColors colors,
    required CabinetTheme theme,
  }) {
    final isEarned = achievedDate != null;
    final date = isEarned ? DateTime.tryParse(achievedDate) : null;
    // 미해금 진행률 0~1 (clamp가 1.0 캡 — 삼항 불필요)
    final progress = (totalWords / CabinetWordGarden.maxGardenWords).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: colors.ink,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: colors.paper2,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: colors.inkLineStrong, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 상단 구분선 장식
            Row(
              children: [
                Expanded(child: Divider(color: colors.inkLineStrong)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(
                    Icons.eco,
                    size: 16,
                    color: isEarned ? colors.accent3 : colors.ink3,
                  ),
                ),
                Expanded(child: Divider(color: colors.inkLineStrong)),
              ],
            ),
            const SizedBox(height: 20),

            // 직인 도장 (해금: 컬러 트로피 / 미해금: 실루엣 + 진행 링 + 잠금 뱃지)
            Center(
              child: Transform.rotate(
                angle: -0.08,
                child: SizedBox(
                  width: 84,
                  height: 84,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isEarned
                              ? colors.accent.withValues(alpha: 0.12)
                              : colors.paper3,
                          border: Border.all(
                            color:
                                isEarned ? colors.accent : colors.inkLineStrong,
                            width: 2.4,
                          ),
                        ),
                        child: Icon(
                          Icons.emoji_events,
                          size: 34,
                          // 미해금: 회색 실루엣 (아이콘 형태 유지)
                          color: isEarned ? colors.accent : colors.inkLineStrong,
                        ),
                      ),
                      // 미해금: 진행 링 (단계별 색상)
                      if (!isEarned)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 3.5,
                              strokeCap: StrokeCap.round,
                              backgroundColor: colors.inkLine,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                colors.progressHeat(progress),
                              ),
                            ),
                          ),
                        ),
                      if (!isEarned)
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: CabinetLockBadge(
                            colors: colors,
                            diameter: 22,
                            iconSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 미해금: 진행 텍스트 (현재 / 목표 단어 수)
            if (!isEarned) ...[
              Text(
                '${AchievementService.formatCount(totalWords)} / ${AchievementService.formatCount(CabinetWordGarden.maxGardenWords)}단어 · ${(progress * 100).round()}%',
                textAlign: TextAlign.center,
                style: theme.labelMono.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: colors.progressHeat(progress),
                ),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 4),

            Text(
              'MASTER GARDENER',
              textAlign: TextAlign.center,
              style: theme.labelMono.copyWith(
                fontSize: 13,
                letterSpacing: 4,
                color: isEarned ? colors.accent : colors.ink3,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Certificate of Achievement',
              textAlign: TextAlign.center,
              style: theme.displaySerif.copyWith(fontSize: 30),
            ),
            const SizedBox(height: 14),
            Text(
              isEarned
                  ? '이 수료증은 단어 2,000개를 모아\nLinguistic Cabinet의 정원을 만개(레벨 20)시킨 공로를 증명합니다.'
                  : '단어 2,000개를 모아 정원을 만개(레벨 20)시키면\n이 수료증이 발급됩니다.',
              textAlign: TextAlign.center,
              style: theme.meaningSerif.copyWith(
                fontSize: 15,
                color: colors.ink2,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            // 해금: 달성 조건 ✓ 스트립 (가이드 조건 카드와 동일한 달성 스타일)
            if (isEarned) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CabinetAchievedChip(
                    text: '2,000단어 모으기',
                    colors: colors,
                  ),
                  const SizedBox(width: 8),
                  CabinetAchievedChip(
                    text: '레벨 20 만개 달성',
                    colors: colors,
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],

            // 통계 (해금 시 accent 테두리로 달성 상태 강조)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.paper3,
                borderRadius: BorderRadius.circular(2),
                border: Border.all(
                  color: isEarned
                      ? colors.accent.withValues(alpha: 0.5)
                      : colors.inkLine,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  _buildStat('COLLECTED', '$totalWords', colors, theme),
                  _buildStat('MASTERED', '$mastered', colors, theme),
                  _buildStat('STREAK', '$streak DAYS', colors, theme),
                  _buildStat('REVIEWS', '$reviews', colors, theme),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // 서명 + 날짜 + 도장
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'The Cabinet Curator',
                        style: theme.labelMono.copyWith(fontSize: 10),
                      ),
                      const SizedBox(height: 4),
                      Container(height: 1, color: colors.inkLineStrong),
                      const SizedBox(height: 6),
                      Text(
                        '정원사 (Curator)',
                        style: theme.handNote.copyWith(fontSize: 15),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Date of Achievement',
                        style: theme.labelMono.copyWith(fontSize: 10),
                      ),
                      const SizedBox(height: 4),
                      Container(height: 1, color: colors.inkLineStrong),
                      const SizedBox(height: 6),
                      Text(
                        date == null
                            ? '——————'
                            : '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}',
                        style: theme.handNote.copyWith(fontSize: 15),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                if (isEarned)
                  Transform.rotate(
                    angle: -0.14,
                    child: CabinetStamp(
                      text: 'ACHIEVED',
                      color: colors.accent,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 28),

            // 액션 버튼
            Row(
              children: [
                Expanded(
                  child: CabinetBrutalButton(
                    text: '업적 컬렉션',
                    icon: Icons.emoji_events_outlined,
                    bg: colors.paper2,
                    textColor: colors.ink,
                    fullWidth: true,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const AchievementCollectionScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CabinetBrutalButton(
                    text: isEarned ? '정원 보러 가기' : '단어 모으러 가기',
                    icon: isEarned ? Icons.eco : Icons.add,
                    fullWidth: true,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(
    String label,
    String value,
    CabinetColors colors,
    CabinetTheme theme,
  ) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: theme.labelMono.copyWith(
              fontSize: 8,
              color: colors.ink3,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: theme.displaySerif.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: colors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
