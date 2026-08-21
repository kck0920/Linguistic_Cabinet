/// 종이 배경·카드·버튼·테이프·스탬프 등 서피스 계열 공용 위젯
library;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/cabinet_colors.dart';
import '../../core/theme/cabinet_theme.dart';

class CabinetPaperScaffold extends StatelessWidget {
  final Widget body;
  final CabinetColors colors;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;

  const CabinetPaperScaffold({
    super.key,
    required this.body,
    required this.colors,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.paper,
      appBar: appBar,
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _PaperBackgroundPainter(colors: colors),
            ),
          ),
          SafeArea(child: body),
        ],
      ),
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }
}

class _PaperBackgroundPainter extends CustomPainter {
  final CabinetColors colors;
  _PaperBackgroundPainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = colors.inkLine
      ..strokeWidth = 1.0;

    // 28px 간격 가로 노트선
    for (double y = 28; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PaperBackgroundPainter oldDelegate) =>
      oldDelegate.colors.mode != colors.mode;
}

/// 2. Paper Card Surface
class CabinetPaperCard extends StatelessWidget {
  final Widget child;
  final CabinetColors colors;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final VoidCallback? onTap;

  const CabinetPaperCard({
    super.key,
    required this.child,
    required this.colors,
    this.padding,
    this.width,
    this.height,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.paper2,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: colors.inkLineStrong, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: MouseRegion(cursor: SystemMouseCursors.click, child: content),
      );
    }

    return content;
  }
}

/// 3. Catalog Card (도서관 색인 카드)
class CabinetCatalogCard extends StatelessWidget {
  final String catalogNo;
  final String english;
  final String? ipa;
  final String? pos;
  final String korean;
  final String? tag;
  final int mastery; // 0 to 5
  final CabinetColors colors;
  final VoidCallback? onTap;
  final double rotateDegrees;

  const CabinetCatalogCard({
    super.key,
    required this.catalogNo,
    required this.english,
    this.ipa,
    this.pos,
    required this.korean,
    this.tag,
    this.mastery = 0,
    required this.colors,
    this.onTap,
    this.rotateDegrees = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = CabinetTheme(colors);

    Widget card = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.paper2, colors.paper3],
        ),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: colors.inkLineStrong, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 상단 붉은 줄 (22px 위치)
          Positioned(
            top: 22,
            left: 0,
            right: 0,
            child: Container(height: 1, color: colors.accent.withValues(alpha: 0.65)),
          ),
          // 하단 펀치홀
          Positioned(
            bottom: 6,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.paper,
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 1,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        catalogNo,
                        style: theme.catalogNo,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (tag != null && tag!.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          tag!.toUpperCase(),
                          style: theme.labelMono.copyWith(fontSize: 9),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  english,
                  style: theme.wordTitle.copyWith(fontSize: 22),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (ipa != null || pos != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${pos != null ? '$pos ' : ''}${ipa ?? ''}',
                    style: theme.labelMono.copyWith(
                      color: colors.ink3,
                      fontSize: 11,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  korean,
                  style: theme.meaningSerif.copyWith(
                    fontSize: 14,
                    color: colors.ink2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Mastery dots
                    Row(
                      children: List.generate(5, (index) {
                        final filled = index < mastery;
                        return Container(
                          margin: const EdgeInsets.only(right: 3),
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: filled
                                ? colors.accent
                                : colors.inkLineStrong.withValues(alpha: 0.3),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (rotateDegrees != 0) {
      card = Transform.rotate(
        angle: rotateDegrees * (math.pi / 180),
        child: card,
      );
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: MouseRegion(cursor: SystemMouseCursors.click, child: card),
      );
    }

    return card;
  }
}

/// 4. Neo-Brutal Button
class CabinetBrutalButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final IconData? icon;
  final Color? bg;
  final Color? textColor;
  final bool fullWidth;

  const CabinetBrutalButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.bg,
    this.textColor,
    this.fullWidth = false,
  });

  @override
  State<CabinetBrutalButton> createState() => _CabinetBrutalButtonState();
}

class _CabinetBrutalButtonState extends State<CabinetBrutalButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.bg ?? const Color(0xFFF5A623);
    final inkColor = widget.textColor ?? const Color(0xFF1A1108);

    final double offset = _isPressed ? 1.0 : 4.0;

    Widget btn = GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        margin: EdgeInsets.only(
          left: _isPressed ? 3 : 0,
          top: _isPressed ? 3 : 0,
          right: _isPressed ? 0 : 3,
          bottom: _isPressed ? 0 : 3,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: inkColor, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: inkColor,
              offset: Offset(offset, offset),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, size: 16, color: inkColor),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  widget.text.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: inkColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.fullWidth) {
      return SizedBox(width: double.infinity, child: btn);
    }
    return btn;
  }
}

/// 5. Masking Tape Widget
class CabinetTape extends StatelessWidget {
  final double rotateDegrees;
  final Color? color;
  final double width;
  final double height;

  const CabinetTape({
    super.key,
    this.rotateDegrees = -6.0,
    this.color,
    this.width = 78,
    this.height = 22,
  });

  @override
  Widget build(BuildContext context) {
    final tapeColor = color ?? const Color(0x8CBEBE50);
    return Transform.rotate(
      angle: rotateDegrees * (math.pi / 180),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: tapeColor,
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 3,
              offset: Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }
}

/// 6. Stamp UI (도장)
class CabinetStamp extends StatelessWidget {
  final String text;
  final Color color;
  final double rotateDegrees;
  final double fontSize;

  const CabinetStamp({
    super.key,
    required this.text,
    required this.color,
    this.rotateDegrees = -12.0,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotateDegrees * (math.pi / 180),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 2.2),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          text.toUpperCase(),
          style: GoogleFonts.jetBrainsMono(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 1.8,
          ),
        ),
      ),
    );
  }
}

/// 7. Section Header
class CabinetSectionHead extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? subtitle;
  final CabinetColors colors;

  const CabinetSectionHead({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final theme = CabinetTheme(colors);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(eyebrow.toUpperCase(), style: theme.labelMono),
        const SizedBox(height: 2),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 4,
          children: [
            Text(title, style: theme.displaySerif),
            if (subtitle != null)
              Text(
                subtitle!,
                style: theme.labelMono.copyWith(color: colors.ink3),
              ),
          ],
        ),
      ],
    );
  }
}

/// 8. Word Garden (CustomPainter 식물 위젯)
/// 단어 수에 따라 0~20레벨로 성장. 최종 레벨(20)은 2,000단어.
/// 임계값 공식: 레벨 n (n>=1) 도달에 5 * n^2 단어 필요 → 5, 20, 45, 80, ..., 2000
