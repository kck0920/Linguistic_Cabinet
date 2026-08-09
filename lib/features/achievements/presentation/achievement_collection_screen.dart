import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/cabinet_colors.dart';
import '../../../core/theme/cabinet_theme.dart';
import '../../../shared/widgets/cabinet_widgets.dart';
import '../data/achievement_service.dart';
import '../data/models/achievement.dart';
import 'achievement_detail_screen.dart';

/// 컬렉션 화면 섹션 순서 (라벨은 [AchievementService.categoryLabel] 공용 사용).
const List<AchievementCategory> _sectionOrder = [
  AchievementCategory.word,
  AchievementCategory.mastered,
  AchievementCategory.streak,
  AchievementCategory.monthly,
  AchievementCategory.master,
];

/// 업적 컬렉션: 수집한 업적을 Apple Fitness 스타일의 원형 배지로 보여준다.
/// 해금 배지는 컬러 그라데이션 원 + 반짝임, 미해금 배지는 흐릿한 원 + 진행도 링.
class AchievementCollectionScreen extends ConsumerWidget {
  const AchievementCollectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(cabinetThemeModeProvider);
    final colors = CabinetColors.fromMode(themeMode);
    final theme = CabinetTheme(colors);
    final statusesAsync = ref.watch(achievementStatusesProvider);

    return CabinetPaperScaffold(
      colors: colors,
      appBar: AppBar(
        backgroundColor: colors.paper2,
        foregroundColor: colors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'ACHIEVEMENTS',
          style: theme.labelMono.copyWith(fontSize: 12, letterSpacing: 2),
        ),
      ),
      body: statusesAsync.when(
        data: (statuses) {
          final earned = statuses.where((s) => s.isEarned).length;
          // 카테고리별 그룹화 (정의 순서 유지)
          final groups = <AchievementCategory, List<AchievementStatus>>{};
          for (final s in statuses) {
            groups.putIfAbsent(s.achievement.category, () => []).add(s);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CABINET MERITS', style: theme.labelMono),
                        const SizedBox(height: 2),
                        Text(
                          'Achievement Collection',
                          style: theme.displaySerif.copyWith(fontSize: 26),
                        ),
                      ],
                    ),
                    Text(
                      '$earned / ${statuses.length}',
                      style: theme.labelMono.copyWith(color: colors.accent),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: statuses.isEmpty ? 0 : earned / statuses.length,
                  minHeight: 5,
                  backgroundColor: colors.inkLine,
                  valueColor: AlwaysStoppedAnimation<Color>(colors.accent3),
                ),
                const SizedBox(height: 20),
                for (final category in _sectionOrder) ...[
                  if (groups.containsKey(category)) ...[
                    Text(
                      AchievementService.categoryLabel(category),
                      style: theme.labelMono,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 16,
                      runSpacing: 14,
                      children: [
                        for (final s in groups[category]!)
                          _buildAchievementBadge(
                            s,
                            colors,
                            theme,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AchievementDetailScreen(
                                    status: s,
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 22),
                  ],
                ],
              ],
            ),
          );
        },
        loading: () =>
            Center(child: CircularProgressIndicator(color: colors.accent)),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('업적을 불러오지 못했습니다: $err',
                style: theme.bodySans),
          ),
        ),
      ),
    );
  }

  /// 원형 배지: 진행도 링 + 그라데이션 원 + 캡션(제목/진행).
  /// 탭하면 상세 화면으로 이동한다.
  Widget _buildAchievementBadge(
    AchievementStatus status,
    CabinetColors colors,
    CabinetTheme theme, {
    VoidCallback? onTap,
  }) {
    final a = status.achievement;
    final earned = status.isEarned;
    final date = status.achievedOn;

    return Semantics(
      button: true,
      label: '${a.title} 배지',
      hint: '상세 정보 보기',
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            SizedBox(
              width: 76,
              height: 76,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 진행도 링 (해금 시 완전한 고리)
                  CircularProgressIndicator(
                    value: status.progress,
                    strokeWidth: 4,
                    strokeCap: StrokeCap.round,
                    backgroundColor: colors.inkLine,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      // 미해금: 진행률에 따라 회색→금색→주황으로 달아오른다
                      earned
                          ? a.color
                          : AchievementService.progressRingColor(
                              status.progress,
                              colors,
                            ),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: earned
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color.lerp(a.color, Colors.white, 0.25)!,
                                  a.color,
                                  Color.lerp(a.color, Colors.black, 0.18)!,
                                ],
                              )
                            : null,
                        color: earned ? null : colors.paper3,
                        border: Border.all(
                          color: earned ? colors.paper2 : colors.inkLineStrong,
                          width: earned ? 2.5 : 1.5,
                        ),
                        boxShadow: earned
                            ? [
                                BoxShadow(
                                  color: a.color.withValues(alpha: 0.35),
                                  blurRadius: 14,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        // 미해금: 회색 실루엣 (아이콘 형태 유지)
                        a.icon,
                        color: earned ? Colors.white : colors.inkLineStrong,
                        size: 26,
                      ),
                    ),
                  ),
                  // 해금 배지: 반짝이는 스파클 오버레이
                  if (earned)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CabinetSparkle(color: a.color),
                      ),
                    ),
                  // 미해금 배지: 우하단 잠금 뱃지
                  if (!earned)
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: CabinetLockBadge(colors: colors),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              a.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.labelMono.copyWith(
                fontSize: 9,
                fontWeight: earned ? FontWeight.w700 : FontWeight.w400,
                color: earned ? colors.ink : colors.ink3,
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: 11,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  earned && date != null
                      ? '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}'
                      : '${AchievementService.formatCount(status.current)} / ${AchievementService.formatCount(a.threshold)}${a.progressUnit}',
                  style: theme.labelMono.copyWith(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: earned ? a.color : colors.ink3,
                  ),
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}

