import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/cabinet_colors.dart';
import '../../../../core/theme/cabinet_theme.dart';
import '../../../../shared/widgets/cabinet_widgets.dart';

/// 설정 화면 1번 탭 — 색상 팔레트 선택
class SettingsThemesTab extends ConsumerWidget {
  const SettingsThemesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(cabinetThemeModeProvider);
    final colors = CabinetColors.fromMode(themeMode);
    final theme = CabinetTheme(colors);
    final currentMode = themeMode;

    final themesList = [
      {'mode': CabinetThemeMode.sepia, 'name': 'Sepia Paper', 'sub': 'Classic Archival Paper (Default)'},
      {'mode': CabinetThemeMode.forest, 'name': 'Forest Moss', 'sub': 'Deep Sage & Muted Green'},
      {'mode': CabinetThemeMode.lavender, 'name': 'Lavender Ink', 'sub': 'Soft Violet & Regal Purple'},
      {'mode': CabinetThemeMode.sunset, 'name': 'Sunset Clay', 'sub': 'Warm Terracotta & Mustard'},
      {'mode': CabinetThemeMode.mono, 'name': 'Monochrome', 'sub': 'Minimal Black & Paper White'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SELECT COLOR PALETTE', style: theme.labelMono),
        const SizedBox(height: 14),
        ...themesList.map((t) {
          final mode = t['mode'] as CabinetThemeMode;
          final isSelected = currentMode == mode;
          final paletteColors = CabinetColors.fromMode(mode);

          return GestureDetector(
            onTap: () {
              ref.read(cabinetThemeModeProvider.notifier).setThemeMode(mode);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: paletteColors.paper2,
                borderRadius: BorderRadius.circular(2),
                border: Border.all(
                  color: isSelected ? colors.ink : colors.inkLineStrong,
                  width: isSelected ? 2.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: paletteColors.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: paletteColors.ink),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t['name'] as String, style: theme.wordTitle.copyWith(fontSize: 18)),
                        Text(t['sub'] as String, style: theme.labelMono.copyWith(color: colors.ink3, fontSize: 10)),
                      ],
                    ),
                  ),
                  if (isSelected)
                    CabinetStamp(text: 'ACTIVE', color: colors.accent, fontSize: 10),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
