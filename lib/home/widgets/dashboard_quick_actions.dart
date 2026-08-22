import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/cabinet_colors.dart';
import '../../core/theme/cabinet_theme.dart';
import '../../shared/widgets/cabinet_widgets.dart';
import '../home_screen.dart';

/// 대시보드 빠른 실행 버튼 — 복습·퀴즈·매칭으로 탭 전환.
class DashboardQuickActions extends ConsumerWidget {
  const DashboardQuickActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(cabinetThemeModeProvider);
    final colors = CabinetColors.fromMode(themeMode);

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
