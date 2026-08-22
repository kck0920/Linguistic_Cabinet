import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/cabinet_colors.dart';
import '../../../../core/theme/cabinet_theme.dart';
import '../../../../shared/widgets/cabinet_widgets.dart';
import '../widgets/settings_themes_tab.dart';
import '../widgets/settings_algo_tab.dart';
import '../widgets/settings_data_tab.dart';
import '../widgets/settings_stats_tab.dart';

/// 설정 화면 — 4개 서브 탭(Themes/Algorithm/Data/Stats)의 셸.
/// 각 탭 UI는 `presentation/widgets/settings_*_tab.dart`에 위임한다.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _activeSubTab = 0; // 0: Themes, 1: Algo, 2: Data, 3: Stats

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(cabinetThemeModeProvider);
    final colors = CabinetColors.fromMode(themeMode);
    final theme = CabinetTheme(colors);

    return CabinetPaperScaffold(
      colors: colors,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CabinetSectionHead(
              eyebrow: 'Section 06 · Settings',
              title: 'Cabinet Preferences',
              subtitle: 'Theme, Spaced Repetition & Data',
              colors: colors,
            ),
            const SizedBox(height: 20),

            // Top Sub Tab Navigation Bar
            CabinetPaperCard(
              colors: colors,
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _buildSubTabButton('THEMES', 0, colors, theme),
                  const SizedBox(width: 4),
                  _buildSubTabButton('ALGORITHM', 1, colors, theme),
                  const SizedBox(width: 4),
                  _buildSubTabButton('DATA & BACKUP', 2, colors, theme),
                  const SizedBox(width: 4),
                  _buildSubTabButton('STATISTICS', 3, colors, theme),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Sub Tab Content
            Expanded(
              child: SingleChildScrollView(
                child: _buildSubTabContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubTabButton(String label, int index, CabinetColors colors, CabinetTheme theme) {
    final isSelected = _activeSubTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeSubTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected ? colors.paper3 : Colors.transparent,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: isSelected ? colors.inkLineStrong : Colors.transparent,
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.labelMono.copyWith(
                fontSize: 9.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? colors.accent : colors.ink2,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubTabContent() {
    switch (_activeSubTab) {
      case 0:
        return const SettingsThemesTab();
      case 1:
        return const SettingsAlgoTab();
      case 2:
        return const SettingsDataTab();
      case 3:
        return const SettingsStatsTab();
      default:
        return const SettingsThemesTab();
    }
  }
}
