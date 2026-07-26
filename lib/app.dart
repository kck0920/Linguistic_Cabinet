import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/cabinet_colors.dart';
import 'core/theme/cabinet_theme.dart';
import 'home/home_screen.dart';
import 'features/review/data/repositories/review_repository.dart';

final _reviewRepo = ReviewRepository();

class VocaTreeApp extends ConsumerWidget {
  const VocaTreeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cabinetThemeMode = ref.watch(cabinetThemeModeProvider);
    final cabinetColors = CabinetColors.fromMode(cabinetThemeMode);
    final cabinetTheme = CabinetTheme(cabinetColors);

    return MaterialApp(
      title: 'Cabinet — Personal English Vocabulary App',
      debugShowCheckedModeBanner: false,
      theme: cabinetTheme.themeData,
      home: const HomeScreen(),
    );
  }
}

final darkModeProvider = StateNotifierProvider<DarkModeNotifier, bool>((ref) {
  return DarkModeNotifier();
});

class DarkModeNotifier extends StateNotifier<bool> {
  DarkModeNotifier() : super(false) {
    _loadDarkMode();
  }

  Future<void> _loadDarkMode() async {
    final value = await _reviewRepo.getSetting('dark_mode');
    if (value != null) {
      state = value == 'true';
    }
  }

  Future<void> setDarkMode(bool value) async {
    await _reviewRepo.setSetting('dark_mode', value.toString());
    state = value;
  }
}

final primaryColorProvider = StateNotifierProvider<PrimaryColorNotifier, Color>((ref) {
  return PrimaryColorNotifier();
});

class PrimaryColorNotifier extends StateNotifier<Color> {
  PrimaryColorNotifier() : super(const Color(0xFFB8562D)) {
    _loadPrimaryColor();
  }

  Future<void> _loadPrimaryColor() async {
    final value = await _reviewRepo.getSetting('primary_color');
    if (value != null) {
      state = Color(int.parse(value));
    }
  }

  Future<void> setPrimaryColor(Color color) async {
    await _reviewRepo.setSetting('primary_color', '0x${color.toARGB32().toRadixString(16).padLeft(8, '0')}');
    state = color;
  }
}
