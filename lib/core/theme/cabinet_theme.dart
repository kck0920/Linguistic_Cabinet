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
    'Noto Sans KR',
    'Apple SD Gothic Neo',
    'Malgun Gothic',
    'Noto Sans',
    'Segoe UI',
    'Roboto',
    'sans-serif',
  ];

  TextStyle get displaySerif => GoogleFonts.notoSansKr(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        color: colors.ink,
        letterSpacing: -0.4,
        height: 1.25,
      ).copyWith(fontFamilyFallback: fontFallback);

  TextStyle get wordTitle => GoogleFonts.notoSansKr(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: colors.ink,
        letterSpacing: -0.3,
        height: 1.25,
      ).copyWith(fontFamilyFallback: fontFallback);

  TextStyle get wordBig => GoogleFonts.notoSansKr(
        fontSize: 44,
        fontWeight: FontWeight.w700,
        color: colors.ink,
        letterSpacing: -0.6,
        height: 1.2,
      ).copyWith(fontFamilyFallback: fontFallback);

  TextStyle get wordHuge => GoogleFonts.notoSansKr(
        fontSize: 56,
        fontWeight: FontWeight.w600,
        color: colors.ink,
        letterSpacing: -0.6,
        height: 1.15,
      ).copyWith(fontFamilyFallback: fontFallback);

  TextStyle get meaningSerif => GoogleFonts.notoSansKr(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: colors.ink,
        height: 1.4,
      ).copyWith(fontFamilyFallback: fontFallback);

  TextStyle get bodySans => GoogleFonts.notoSansKr(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: colors.ink,
        height: 1.5,
      ).copyWith(fontFamilyFallback: fontFallback);

  TextStyle get labelMono => GoogleFonts.notoSansKr(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: colors.ink3,
        letterSpacing: 0.4,
        height: 1.35,
      ).copyWith(fontFamilyFallback: fontFallback);

  TextStyle get catalogNo => GoogleFonts.notoSansKr(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: colors.ink3,
        letterSpacing: 0.5,
        height: 1.35,
      ).copyWith(fontFamilyFallback: fontFallback);

  TextStyle get handNote => GoogleFonts.notoSansKr(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: colors.accent,
        height: 1.5,
      ).copyWith(fontFamilyFallback: fontFallback);

  TextStyle get brutalButtonText => GoogleFonts.notoSansKr(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: colors.brutalInk,
        letterSpacing: 0.2,
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
    final baseTextTheme = GoogleFonts.notoSansKrTextTheme(
      ThemeData.light().textTheme,
    ).apply(
      bodyColor: colors.ink,
      displayColor: colors.ink,
    );

    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: colors.paper,
      primaryColor: colors.accent,
      fontFamily: GoogleFonts.notoSansKr().fontFamily,
      fontFamilyFallback: fontFallback,
      colorScheme: ColorScheme.light(
        primary: colors.accent,
        secondary: colors.accent2,
        surface: colors.paper2,
        onSurface: colors.ink,
      ),
      textTheme: baseTextTheme.copyWith(
        bodyMedium: bodySans,
        titleMedium: meaningSerif,
      ),
    );
  }
}

