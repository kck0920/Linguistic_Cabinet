import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'cabinet_colors.dart';

final cabinetThemeModeProvider = StateNotifierProvider<CabinetThemeModeNotifier, CabinetThemeMode>((ref) {
  return CabinetThemeModeNotifier();
});

class CabinetThemeModeNotifier extends StateNotifier<CabinetThemeMode> {
  CabinetThemeModeNotifier() : super(CabinetThemeMode.sepia);

  void setThemeMode(CabinetThemeMode mode) {
    state = mode;
  }

  void setThemeByName(String name) {
    switch (name.toLowerCase()) {
      case 'forest':
        state = CabinetThemeMode.forest;
        break;
      case 'lavender':
        state = CabinetThemeMode.lavender;
        break;
      case 'sunset':
        state = CabinetThemeMode.sunset;
        break;
      case 'mono':
      case 'monochrome':
        state = CabinetThemeMode.mono;
        break;
      case 'sepia':
      default:
        state = CabinetThemeMode.sepia;
        break;
    }
  }
}

class CabinetTheme {
  final CabinetColors colors;

  CabinetTheme(this.colors);

  TextStyle get displaySerif => GoogleFonts.fraunces(
        fontSize: 32,
        fontWeight: FontWeight.w300,
        fontStyle: FontStyle.italic,
        color: colors.ink,
        letterSpacing: -0.6,
      );

  TextStyle get wordTitle => GoogleFonts.fraunces(
        fontSize: 26,
        fontWeight: FontWeight.w500,
        color: colors.ink,
        letterSpacing: -0.4,
      );

  TextStyle get wordBig => GoogleFonts.fraunces(
        fontSize: 48,
        fontWeight: FontWeight.w400,
        color: colors.ink,
        letterSpacing: -0.8,
      );

  TextStyle get wordHuge => GoogleFonts.fraunces(
        fontSize: 64,
        fontWeight: FontWeight.w300,
        fontStyle: FontStyle.italic,
        color: colors.ink,
        height: 1.0,
      );

  TextStyle get meaningSerif => GoogleFonts.fraunces(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        color: colors.ink,
      );

  TextStyle get bodySans => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: colors.ink,
      );

  TextStyle get labelMono => GoogleFonts.jetBrainsMono(
        fontSize: 10,
        fontWeight: FontWeight.w400,
        color: colors.ink3,
        letterSpacing: 1.6,
      );

  TextStyle get catalogNo => GoogleFonts.jetBrainsMono(
        fontSize: 10,
        fontWeight: FontWeight.w400,
        color: colors.ink3,
        letterSpacing: 1.4,
      );

  TextStyle get handNote => GoogleFonts.caveat(
        fontSize: 19,
        fontWeight: FontWeight.w500,
        color: colors.accent,
      );

  TextStyle get brutalButtonText => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: colors.brutalInk,
        letterSpacing: 0.4,
      );

  ThemeData get themeData {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: colors.paper,
      primaryColor: colors.accent,
      colorScheme: ColorScheme.light(
        primary: colors.accent,
        secondary: colors.accent2,
        surface: colors.paper2,
        onSurface: colors.ink,
      ),
      textTheme: TextTheme(
        bodyMedium: bodySans,
        titleMedium: meaningSerif,
      ),
    );
  }
}
