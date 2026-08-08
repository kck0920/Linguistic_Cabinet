import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/cabinet_colors.dart';
import '../../../core/theme/cabinet_theme.dart';
import '../../../shared/widgets/cabinet_widgets.dart';
import '../../words/presentation/screens/word_form_screen.dart';
import '../../words/presentation/screens/word_list_screen.dart';
import '../data/achievement_service.dart';
import 'achievement_collection_screen.dart';
import 'master_garden_certificate_screen.dart';

/// 마스터 정원 배지 해금 조건 안내 화면.
/// 미해금 배지 카드를 탭하면 열려, 해금 조건·현재 진행도·남은 단어 수를 보여준다.
class MasterGardenGuideScreen extends ConsumerStatefulWidget {
  const MasterGardenGuideScreen({super.key});

  @override
  ConsumerState<MasterGardenGuideScreen> createState() =>
      _MasterGardenGuideScreenState();
}

class _MasterGardenGuideScreenState
    extends ConsumerState<MasterGardenGuideScreen> {
  /// 해금 직후 축하 confetti를 화면당 한 번만 재생한다.
  bool _playedConfetti = false;
  bool _showConfetti = false;

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(cabinetThemeModeProvider);
    final colors = CabinetColors.fromMode(themeMode);
    final theme = CabinetTheme(colors);

    final wordsAsync = ref.watch(wordListProvider);
    final totalCount = wordsAsync.value?.length ?? 0;
    final progress =
        (totalCount / CabinetWordGarden.maxGardenWords).clamp(0.0, 1.0);
    final remaining = CabinetWordGarden.maxGardenWords - totalCount;
    // 배지 해금 여부: 가이드가 열린 동안에도 (단어 추가·컬렉션 자가수여로)
    // 해금될 수 있어, CTA 복귀 시마다 다시 읽는다.
    final badgeAsync = ref.watch(masterGardenBadgeProvider);
    final isEarned = badgeAsync.valueOrNull != null;

    // 해금 상태로 진입(또는 전환)하면 짧은 축하 confetti를 한 번 재생한다.
    if (isEarned && !_playedConfetti) {
      _playedConfetti = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _showConfetti = true);
      });
    }

    return Stack(
      children: [
        CabinetPaperScaffold(
          colors: colors,
          appBar: AppBar(
        backgroundColor: colors.paper2,
        foregroundColor: colors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'BADGE GUIDE',
          style: theme.labelMono.copyWith(fontSize: 12, letterSpacing: 2),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),

                // ── 큰 배지: 해금 시 컬러 배지, 미해금 시 잠긴 배지 ─
                Center(
                  child: SizedBox(
                    width: 168,
                    height: 168,
                    child: isEarned
                        ? _buildEarnedBadge(colors)
                        : CabinetLockedBadge(
                            progress: progress,
                            colors: colors,
                            size: 168,
                            icon: Icons.emoji_events,
                          ),
                  ),
                ),
                const SizedBox(height: 18),

                // ── 제목 / 상태 ───────────────────────────────────────
                Text(
                  'MASTER GARDENER',
                  textAlign: TextAlign.center,
                  style: theme.displaySerif.copyWith(fontSize: 30),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    isEarned ? '해금 완료! 🎉' : '아직 잠겨 있어요',
                    style: theme.labelMono.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isEarned ? colors.accent : colors.ink3,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── 해금 조건 카드 ─────────────────────────────────────
                CabinetPaperCard(
                  colors: colors,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      _buildConditionRow(
                        theme,
                        colors,
                        icon: Icons.eco_outlined,
                        label: '단어 수집',
                        value:
                            '${AchievementService.formatCount(CabinetWordGarden.maxGardenWords)}단어 모으기',
                        achieved: isEarned,
                      ),
                      _buildDivider(colors),
                      _buildConditionRow(
                        theme,
                        colors,
                        icon: Icons.grass_outlined,
                        label: '정원 레벨',
                        value: '레벨 ${CabinetWordGarden.maxGardenLevel} 만개 달성',
                        achieved: isEarned,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── 진행 상황 카드 ─────────────────────────────────────
                CabinetPaperCard(
                  colors: colors,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PROGRESS', style: theme.labelMono),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${AchievementService.formatCount(totalCount)} / ${AchievementService.formatCount(CabinetWordGarden.maxGardenWords)}단어',
                            style: theme.labelMono.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: colors.progressHeat(progress),
                            ),
                          ),
                          Text(
                            '${(progress * 100).round()}%',
                            style: theme.labelMono.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: colors.progressHeat(progress),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: colors.inkLine,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            colors.progressHeat(progress),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isEarned
                            ? '마스터 정원 달성을 축하합니다! 수료증을 확인해 보세요. 🎉'
                            : remaining > 0
                                ? '${AchievementService.formatCount(remaining)}단어를 더 모으면 해금됩니다!'
                                : '조건을 모두 충족했어요! 대시보드에서 수료증을 확인하세요.',
                        style: theme.handNote.copyWith(fontSize: 17),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── CTA ────────────────────────────────────────────────
                // 해금 완료 후엔 '수료증 보러 가기'가 주 CTA가 되고 미리보기는 숨긴다.
                if (isEarned)
                  CabinetBrutalButton(
                    text: '수료증 보러 가기',
                    icon: Icons.description_outlined,
                    fullWidth: true,
                    onPressed: () => _openAndRefresh(
                      (_) => const MasterGardenCertificateScreen(),
                    ),
                  )
                else
                  CabinetBrutalButton(
                    text: '단어 모으러 가기',
                    icon: Icons.add,
                    fullWidth: true,
                    onPressed: () => _openAndRefresh(
                      (_) => const WordFormScreen(),
                    ),
                  ),
                const SizedBox(height: 10),
                if (!isEarned) ...[
                  CabinetBrutalButton(
                    text: '수료증 미리보기',
                    icon: Icons.description_outlined,
                    bg: colors.paper2,
                    textColor: colors.ink,
                    fullWidth: true,
                    onPressed: () => _openAndRefresh(
                      (_) => const MasterGardenCertificateScreen(),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                CabinetBrutalButton(
                  text: '업적 컬렉션 보기',
                  icon: Icons.emoji_events_outlined,
                  bg: colors.paper2,
                  textColor: colors.ink,
                  fullWidth: true,
                  onPressed: () => _openAndRefresh(
                    (_) => const AchievementCollectionScreen(),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        ),
        ),
        // 해금 축하 confetti (화면 전체, 터치는 통과)
        if (_showConfetti)
          Positioned.fill(
            child: IgnorePointer(
              child: CabinetConfettiOverlay(
                colors: colors,
                big: true,
                onFinished: () => setState(() => _showConfetti = false),
              ),
            ),
          ),
      ],
    );
  }

  /// CTA 화면(단어 추가·수료증·업적 컬렉션)에서 돌아오면 단어 수·배지 상태를
  /// 다시 읽어 진행도가 즉시 갱신되도록 한다 (세 CTA 공용).
  void _openAndRefresh(WidgetBuilder builder) {
    Navigator.push(context, MaterialPageRoute(builder: builder)).then((_) {
      ref.invalidate(wordListProvider);
      ref.invalidate(filteredWordsProvider);
      ref.invalidate(masterGardenBadgeProvider);
    });
  }

  /// 해금된 마스터 정원 배지: 컬러 원 + 트로피 + ACHIEVED 스탬프.
  Widget _buildEarnedBadge(CabinetColors colors) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.accent,
            border: Border.all(color: colors.ink, width: 3),
            boxShadow: [
              BoxShadow(
                color: colors.accent.withValues(alpha: 0.35),
                blurRadius: 26,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(Icons.emoji_events, color: colors.paper, size: 56),
        ),
        Positioned(
          right: 6,
          bottom: 12,
          child: Transform.rotate(
            angle: -0.15,
            child: CabinetStamp(
              text: 'ACHIEVED',
              color: colors.paper,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(CabinetColors colors) => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(vertical: 12),
        color: colors.inkLine,
      );

  /// [achieved]가 true면 조건이 충족됐다는 '달성 ✓' 스타일로 표시한다.
  Widget _buildConditionRow(
    CabinetTheme theme,
    CabinetColors colors, {
    required IconData icon,
    required String label,
    required String value,
    bool achieved = false,
  }) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: achieved
                ? colors.accent.withValues(alpha: 0.14)
                : colors.paper3,
            border: Border.all(
              color: achieved ? colors.accent : colors.inkLineStrong,
              width: 1.2,
            ),
          ),
          child: Icon(
            achieved ? Icons.check : icon,
            size: 17,
            color: achieved ? colors.accent : colors.ink3,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: theme.labelMono.copyWith(
            fontSize: 9,
            color: achieved ? colors.accent : null,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: theme.bodySans.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: achieved ? colors.accent : colors.ink,
            ),
          ),
        ),
        // 해금 시 '달성 완료' 보조 배지 (공용 위젯, 칩 안에 ✓ 포함)
        if (achieved) ...[
          const SizedBox(width: 6),
          CabinetAchievedChip(
            text: '달성 완료',
            colors: colors,
            fontSize: 8,
          ),
        ],
      ],
    );
  }
}
