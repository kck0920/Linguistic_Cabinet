import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
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

  static const List<String> fontFallback = [
    'Noto Sans',
    'Apple SD Gothic Neo',
    'Malgun Gothic',
    'Segoe UI',
    'Roboto',
    'sans-serif',
  ];

  TextStyle get displaySerif => GoogleFonts.fraunces(
        fontSize: 32,
        fontWeight: FontWeight.w300,
        fontStyle: FontStyle.italic,
        color: colors.ink,
        letterSpacing: -0.6,
      ).copyWith(fontFamilyFallback: fontFallback);

  TextStyle get wordTitle => GoogleFonts.fraunces(
        fontSize: 26,
        fontWeight: FontWeight.w500,
        color: colors.ink,
        letterSpacing: -0.4,
      ).copyWith(fontFamilyFallback: fontFallback);

  TextStyle get wordBig => GoogleFonts.fraunces(
        fontSize: 48,
        fontWeight: FontWeight.w400,
        color: colors.ink,
        letterSpacing: -0.8,
      ).copyWith(fontFamilyFallback: fontFallback);

  TextStyle get wordHuge => GoogleFonts.fraunces(
        fontSize: 64,
        fontWeight: FontWeight.w300,
        fontStyle: FontStyle.italic,
        color: colors.ink,
        height: 1.0,
      ).copyWith(fontFamilyFallback: fontFallback);

  TextStyle get meaningSerif => GoogleFonts.fraunces(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        color: colors.ink,
      ).copyWith(fontFamilyFallback: fontFallback);

  TextStyle get bodySans => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: colors.ink,
      ).copyWith(fontFamilyFallback: fontFallback);

  TextStyle get labelMono => GoogleFonts.jetBrainsMono(
        fontSize: 10,
        fontWeight: FontWeight.w400,
        color: colors.ink3,
        letterSpacing: 1.6,
      ).copyWith(fontFamilyFallback: fontFallback);

  TextStyle get catalogNo => GoogleFonts.jetBrainsMono(
        fontSize: 10,
        fontWeight: FontWeight.w400,
        color: colors.ink3,
        letterSpacing: 1.4,
      ).copyWith(fontFamilyFallback: fontFallback);

  TextStyle get handNote => GoogleFonts.caveat(
        fontSize: 19,
        fontWeight: FontWeight.w500,
        color: colors.accent,
      ).copyWith(fontFamilyFallback: fontFallback);

  TextStyle get brutalButtonText => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: colors.brutalInk,
        letterSpacing: 0.4,
      ).copyWith(fontFamilyFallback: fontFallback);

  MarkdownStyleSheet buildMarkdownStyle({double fontSize = 16, Color? textColor}) {
    final baseColor = textColor ?? colors.ink;
    final baseStyle = handNote.copyWith(fontSize: fontSize, color: baseColor);
    final headerStyle = bodySans.copyWith(fontWeight: FontWeight.w700, color: baseColor);

    return MarkdownStyleSheet(
      p: baseStyle,
      h1: headerStyle.copyWith(fontSize: fontSize + 6),
      h2: headerStyle.copyWith(fontSize: fontSize + 4),
      h3: headerStyle.copyWith(fontSize: fontSize + 2),
      h4: headerStyle.copyWith(fontSize: fontSize + 1),
      h5: headerStyle.copyWith(fontSize: fontSize),
      h6: headerStyle.copyWith(fontSize: fontSize - 1),
      listBullet: baseStyle,
      tableBody: baseStyle,
      blockquote: baseStyle.copyWith(fontStyle: FontStyle.italic),
      code: GoogleFonts.jetBrainsMono(
        fontSize: fontSize - 2,
        color: colors.accent,
      ).copyWith(fontFamilyFallback: fontFallback),
      strong: baseStyle.copyWith(fontWeight: FontWeight.w700),
      em: baseStyle.copyWith(fontStyle: FontStyle.italic),
    );
  }

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

