import 'package:flutter/material.dart';
import '../../core/theme/cabinet_colors.dart';
import '../../core/theme/cabinet_theme.dart';
import '../../features/achievements/presentation/achievement_collection_screen.dart';

/// 업적 컬렉션 진입 버튼 (배지 카드 바로 아래).
class DashboardAchievementsEntry extends StatelessWidget {
  const DashboardAchievementsEntry({
    super.key,
    required this.colors,
    required this.theme,
  });

  final CabinetColors colors;
  final CabinetTheme theme;

  @override
  Widget build(BuildContext context) {
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
}
