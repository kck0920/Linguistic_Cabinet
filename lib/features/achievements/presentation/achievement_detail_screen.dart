import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/cabinet_colors.dart';
import '../../../core/theme/cabinet_theme.dart';
import '../../../shared/widgets/cabinet_widgets.dart';
import '../data/achievement_service.dart';
import '../data/models/achievement.dart';

/// 업적 배지 상세 화면: 컬렉션의 원형 배지를 탭하면 열린다.
/// 큰 배지(진행 링 + 그라데이션 원) + 달성 날짜/설명/진행 정보를 보여준다.
class AchievementDetailScreen extends ConsumerWidget {
  final AchievementStatus status;

  const AchievementDetailScreen({super.key, required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(cabinetThemeModeProvider);
    final colors = CabinetColors.fromMode(themeMode);
    final theme = CabinetTheme(colors);
    final a = status.achievement;
    final earned = status.isEarned;
    final date = status.achievedOn;

    return CabinetPaperScaffold(
      colors: colors,
      appBar: AppBar(
        backgroundColor: colors.paper2,
        foregroundColor: colors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'BADGE DETAIL',
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

                // ── 큰 배지 ───────────────────────────────────────────
                // 미해금: 공용 잠긴 배지 (진행 링 + 실루엣 + 잠금 뱃지)
                // 해금: 그라데이션 원 + 스파클
                Center(
                  child: SizedBox(
                    width: 168,
                    height: 168,
                    child: earned
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              // 진행도 링 (완전한 고리)
                              CircularProgressIndicator(
                                value: status.progress,
                                strokeWidth: 8,
                                strokeCap: StrokeCap.round,
                                backgroundColor: colors.inkLine,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  a.color,
                                ),
                              ),
                              Center(
                                child: Container(
                                  width: 138,
                                  height: 138,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color.lerp(a.color, Colors.white, 0.25)!,
                                        a.color,
                                        Color.lerp(a.color, Colors.black, 0.18)!,
                                      ],
                                    ),
                                    border: Border.all(
                                      color: colors.paper2,
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: a.color.withValues(alpha: 0.4),
                                        blurRadius: 26,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    a.icon,
                                    color: Colors.white,
                                    size: 58,
                                  ),
                                ),
                              ),
                              // 해금 배지: 큰 스파클 오버레이
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: CabinetSparkle(
                                    color: a.color,
                                    scale: 1.7,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : CabinetLockedBadge(
                            progress: status.progress,
                            colors: colors,
                            size: 168,
                            icon: a.icon,
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── 상태 라벨 / 스탬프 ────────────────────────────────
                Center(
                  child: earned
                      ? Transform.rotate(
                          angle: -0.1,
                          child: CabinetStamp(
                            text: 'ACHIEVED',
                            color: a.color,
                            fontSize: 12,
                          ),
                        )
                      : Text(
                          '${AchievementService.formatCount(status.current)} / ${AchievementService.formatCount(a.threshold)}${a.progressUnit}',
                          style: theme.labelMono.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: colors.ink3,
                          ),
                        ),
                ),
                const SizedBox(height: 14),

                // ── 제목 / 카테고리 ────────────────────────────────────
                Text(
                  a.title,
                  textAlign: TextAlign.center,
                  style: theme.displaySerif.copyWith(fontSize: 32),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.paper2,
                      border: Border.all(color: colors.inkLineStrong, width: 1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text(
                      AchievementService.categoryLabel(a.category),
                      style: theme.labelMono.copyWith(fontSize: 9),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // ── 설명 ──────────────────────────────────────────────
                Text(
                  a.description,
                  textAlign: TextAlign.center,
                  style: theme.meaningSerif.copyWith(
                    fontSize: 16,
                    color: colors.ink2,
                  ),
                ),
                const SizedBox(height: 24),

                // ── 상세 정보 카드 ─────────────────────────────────────
                CabinetPaperCard(
                  colors: colors,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        theme,
                        colors,
                        icon: Icons.flag_outlined,
                        label: '조건',
                        value: '${AchievementService.formatCount(a.threshold)}${a.progressUnit}',
                      ),
                      _buildInfoDivider(colors),
                      if (a.month != null) ...[
                        _buildInfoRow(
                          theme,
                          colors,
                          icon: Icons.calendar_month_outlined,
                          label: '대상 달',
                          value: '${a.month}월',
                        ),
                        _buildInfoDivider(colors),
                      ],
                      _buildInfoRow(
                        theme,
                        colors,
                        icon: Icons.speed_outlined,
                        label: '현재 진행',
                        value: earned
                            ? '달성 완료'
                            : '${AchievementService.formatCount(status.current)} / ${AchievementService.formatCount(a.threshold)}${a.progressUnit}',
                      ),
                      _buildInfoDivider(colors),
                      _buildInfoRow(
                        theme,
                        colors,
                        icon: Icons.event_available_outlined,
                        label: '달성 날짜',
                        value: earned && date != null
                            ? '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}'
                            : '아직 미달성',
                        valueColor: earned ? a.color : colors.ink3,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: status.progress,
                    minHeight: 6,
                    backgroundColor: colors.inkLine,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      earned
                          ? a.color
                          : AchievementService.progressRingColor(
                              status.progress,
                              colors,
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  earned
                      ? '이 업적을 달성했습니다!'
                      : '${AchievementService.formatCount(a.threshold - status.current)}${a.progressUnit} 남았습니다',
                  textAlign: TextAlign.center,
                  style: theme.labelMono.copyWith(
                    fontSize: 9,
                    color: colors.ink3,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoDivider(CabinetColors colors) => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(vertical: 12),
        color: colors.inkLine,
      );

  Widget _buildInfoRow(
    CabinetTheme theme,
    CabinetColors colors, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: colors.ink3),
        const SizedBox(width: 10),
        Text(label, style: theme.labelMono.copyWith(fontSize: 9)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: theme.bodySans.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: valueColor ?? colors.ink,
            ),
          ),
        ),
      ],
    );
  }
}
