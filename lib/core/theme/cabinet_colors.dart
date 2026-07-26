import 'package:flutter/material.dart';

enum CabinetThemeMode {
  sepia,
  forest,
  lavender,
  sunset,
  mono,
}

class CabinetColors {
  final CabinetThemeMode mode;

  // Paper Surfaces
  final Color paper;
  final Color paper2;
  final Color paper3;
  final Color paperEdge;

  // Ink Colors
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color ink4;
  final Color inkLine;
  final Color inkLineStrong;

  // Accents
  final Color accent;       // stamp red / primary accent
  final Color accent2;      // mustard
  final Color accent3;      // olive / correct
  final Color accentBlue;   // ink blue

  // Tapes
  final Color tapeYellow;
  final Color tapePink;
  final Color tapeBlue;
  final Color tapeGreen;

  // Neo-Brutal
  final Color brutalBg;
  final Color brutalInk;
  final Color brutalShadow;

  const CabinetColors({
    required this.mode,
    required this.paper,
    required this.paper2,
    required this.paper3,
    required this.paperEdge,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.ink4,
    required this.inkLine,
    required this.inkLineStrong,
    required this.accent,
    required this.accent2,
    required this.accent3,
    required this.accentBlue,
    required this.tapeYellow,
    required this.tapePink,
    required this.tapeBlue,
    required this.tapeGreen,
    required this.brutalBg,
    required this.brutalInk,
    required this.brutalShadow,
  });

  factory CabinetColors.fromMode(CabinetThemeMode mode) {
    switch (mode) {
      case CabinetThemeMode.forest:
        return const CabinetColors(
          mode: CabinetThemeMode.forest,
          paper: Color(0xFFEAEAD9),
          paper2: Color(0xFFE0E3CE),
          paper3: Color(0xFFCBD1B4),
          paperEdge: Color(0xFFA9B590),
          ink: Color(0xFF1F2B1C),
          ink2: Color(0xFF2F4028),
          ink3: Color(0xFF4D5F42),
          ink4: Color(0xFF7A8A6A),
          inkLine: Color(0x281F2B1C),
          inkLineStrong: Color(0x601F2B1C),
          accent: Color(0xFF5F7A3B),
          accent2: Color(0xFF8A6B2A),
          accent3: Color(0xFF2F5140),
          accentBlue: Color(0xFF3B5F7A),
          tapeYellow: Color(0x8CDEE58A),
          tapePink: Color(0x80D28C96),
          tapeBlue: Color(0x807896B4),
          tapeGreen: Color(0x808CAA78),
          brutalBg: Color(0xFFB8D15F),
          brutalInk: Color(0xFF121B10),
          brutalShadow: Color(0xFF121B10),
        );
      case CabinetThemeMode.lavender:
        return const CabinetColors(
          mode: CabinetThemeMode.lavender,
          paper: Color(0xFFEFEAF3),
          paper2: Color(0xFFE6DFEF),
          paper3: Color(0xFFD6CAE4),
          paperEdge: Color(0xFFB8A6CF),
          ink: Color(0xFF241A30),
          ink2: Color(0xFF3B2B52),
          ink3: Color(0xFF5F4A7A),
          ink4: Color(0xFF8C7AA8),
          inkLine: Color(0x28241A30),
          inkLineStrong: Color(0x60241A30),
          accent: Color(0xFF7A4BC6),
          accent2: Color(0xFFB06FB3),
          accent3: Color(0xFF4F6BC4),
          accentBlue: Color(0xFF3C5BA5),
          tapeYellow: Color(0x8CE5C2E0),
          tapePink: Color(0x80D28CB8),
          tapeBlue: Color(0x808C96D2),
          tapeGreen: Color(0x808CAA78),
          brutalBg: Color(0xFFC4A2F0),
          brutalInk: Color(0xFF181024),
          brutalShadow: Color(0xFF181024),
        );
      case CabinetThemeMode.sunset:
        return const CabinetColors(
          mode: CabinetThemeMode.sunset,
          paper: Color(0xFFF6E6D9),
          paper2: Color(0xFFF2D9C6),
          paper3: Color(0xFFEAC2A6),
          paperEdge: Color(0xFFD99C72),
          ink: Color(0xFF2E1611),
          ink2: Color(0xFF52251A),
          ink3: Color(0xFF7B4229),
          ink4: Color(0xFFB2724A),
          inkLine: Color(0x282E1611),
          inkLineStrong: Color(0x602E1611),
          accent: Color(0xFFD94B2E),
          accent2: Color(0xFFE88A2C),
          accent3: Color(0xFFA83A5F),
          accentBlue: Color(0xFF385A7A),
          tapeYellow: Color(0x8CE6BD90),
          tapePink: Color(0x80E09096),
          tapeBlue: Color(0x80809AB4),
          tapeGreen: Color(0x8090B088),
          brutalBg: Color(0xFFFF9558),
          brutalInk: Color(0xFF1E0E0B),
          brutalShadow: Color(0xFF1E0E0B),
        );
      case CabinetThemeMode.mono:
        return const CabinetColors(
          mode: CabinetThemeMode.mono,
          paper: Color(0xFFECECEA),
          paper2: Color(0xFFE2E2E0),
          paper3: Color(0xFFD0D0CD),
          paperEdge: Color(0xFFA6A6A3),
          ink: Color(0xFF131313),
          ink2: Color(0xFF2A2A2A),
          ink3: Color(0xFF4A4A4A),
          ink4: Color(0xFF7A7A7A),
          inkLine: Color(0x24131313),
          inkLineStrong: Color(0x60131313),
          accent: Color(0xFF1A1A1A),
          accent2: Color(0xFF555555),
          accent3: Color(0xFF333333),
          accentBlue: Color(0xFF444444),
          tapeYellow: Color(0x70B0B0B0),
          tapePink: Color(0x70C0C0C0),
          tapeBlue: Color(0x70909090),
          tapeGreen: Color(0x70A0A0A0),
          brutalBg: Color(0xFFF2F2F0),
          brutalInk: Color(0xFF000000),
          brutalShadow: Color(0xFF000000),
        );
      case CabinetThemeMode.sepia:
      default:
        return const CabinetColors(
          mode: CabinetThemeMode.sepia,
          paper: Color(0xFFF1E8D5),
          paper2: Color(0xFFEBE0C8),
          paper3: Color(0xFFE3D5B5),
          paperEdge: Color(0xFFD8C8A3),
          ink: Color(0xFF2A1F16),
          ink2: Color(0xFF4A3A2A),
          ink3: Color(0xFF6F5A44),
          ink4: Color(0xFF9C8365),
          inkLine: Color(0x2E2A1F16),
          inkLineStrong: Color(0x6B2A1F16),
          accent: Color(0xFFB8562D),
          accent2: Color(0xFFC88A2A),
          accent3: Color(0xFF4A6B3A),
          accentBlue: Color(0xFF33556E),
          tapeYellow: Color(0x8CBEBE50),
          tapePink: Color(0x80D28C96),
          tapeBlue: Color(0x807896B4),
          tapeGreen: Color(0x808CAA78),
          brutalBg: Color(0xFFF5A623),
          brutalInk: Color(0xFF1A1108),
          brutalShadow: Color(0xFF1A1108),
        );
    }
  }
}
