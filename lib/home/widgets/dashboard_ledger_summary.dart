import 'package:flutter/material.dart';
import '../../core/theme/cabinet_colors.dart';
import '../../core/theme/cabinet_theme.dart';
import '../../features/achievements/data/achievement_service.dart';

/// 대시보드 LEDGER SUMMARY — 단어·숙달·스트릭·복습 4개 타일.
class DashboardLedgerSummary extends StatelessWidget {
  const DashboardLedgerSummary({
    super.key,
    required this.total,
    required this.mastered,
    required this.streakDays,
    required this.totalReviews,
    required this.colors,
    required this.theme,
  });

  final int total;
  final int mastered;
  final int streakDays;
  final int totalReviews;
  final CabinetColors colors;
  final CabinetTheme theme;

  @override
  Widget build(BuildContext context) {
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
            ),
            _buildStatItem(
              'Mastered',
              total > 0
                  ? '${AchievementService.formatCount(mastered)} / ${AchievementService.formatCount(total)}'
                  : '0',
              colors.paper3,
              isAccent: true,
              subtitle: total > 0 ? '$masteredPct% 숙달' : null,
            ),
            _buildStatItem(
              'Streak',
              '$streakDays ${streakDays == 1 ? 'Day' : 'Days'}',
              colors.paper2,
            ),
            _buildStatItem(
              'Reviews',
              '$totalReviews',
              colors.paper2,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    Color bg, {
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
}
