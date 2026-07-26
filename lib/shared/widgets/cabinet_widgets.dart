import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/cabinet_colors.dart';
import '../../core/theme/cabinet_theme.dart';

/// 1. 종이 수평 노트선 & 대각선 텍스처 배경
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
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: content,
        ),
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
            color: Colors.black.withOpacity(0.1),
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
            child: Container(
              height: 1,
              color: colors.accent.withOpacity(0.65),
            ),
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
                    Text(catalogNo, style: theme.catalogNo),
                    if (tag != null && tag!.isNotEmpty)
                      Text(tag!.toUpperCase(), style: theme.labelMono.copyWith(fontSize: 9)),
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
                    style: theme.labelMono.copyWith(color: colors.ink3, fontSize: 11),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  korean,
                  style: theme.meaningSerif.copyWith(fontSize: 14, color: colors.ink2),
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
                            color: filled ? colors.accent : colors.inkLineStrong.withOpacity(0.3),
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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
              const SizedBox(width: 8),
            ],
            Text(
              widget.text.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: inkColor,
                letterSpacing: 0.8,
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
              Text(subtitle!, style: theme.labelMono.copyWith(color: colors.ink3)),
          ],
        ),
      ],
    );
  }
}

/// 8. Word Garden (CustomPainter 식물 위젯)
class CabinetWordGarden extends StatelessWidget {
  final int plantLevel; // 0 to 4
  final CabinetColors colors;
  final int totalCount;
  final int masteredCount;

  const CabinetWordGarden({
    super.key,
    required this.plantLevel,
    required this.colors,
    this.totalCount = 0,
    this.masteredCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = CabinetTheme(colors);
    // Level calculation thresholds: 0, 5, 12, 20, 30
    final thresholds = [0, 5, 12, 20, 30];
    int calculatedLevel = 0;
    for (int i = 0; i < thresholds.length; i++) {
      if (totalCount >= thresholds[i]) {
        calculatedLevel = i;
      }
    }
    final level = plantLevel.clamp(0, 4) > calculatedLevel ? plantLevel.clamp(0, 4) : calculatedLevel;

    int currentMin = thresholds[level.clamp(0, 4)];
    int nextMin = level < 4 ? thresholds[level + 1] : 30;
    int remaining = level < 4 ? (nextMin - totalCount) : 0;
    double progress = level == 4
        ? 1.0
        : ((totalCount - currentMin) / (nextMin - currentMin)).clamp(0.0, 1.0);

    return CabinetPaperCard(
      colors: colors,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('SECTION · WORD GARDEN', style: theme.labelMono),
              Text('LVL $level / 4', style: theme.labelMono.copyWith(color: colors.accent)),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: SizedBox(
              width: 140,
              height: 140,
              child: CustomPaint(
                painter: _PlantPainter(level: level, colors: colors),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            level == 4
                ? 'Garden Fully Bloomed! 🌸'
                : 'Next bloom in $remaining words ($masteredCount Mastered)',
            style: theme.handNote.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: colors.inkLine,
              valueColor: AlwaysStoppedAnimation<Color>(colors.accent3),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlantPainter extends CustomPainter {
  final int level;
  final CabinetColors colors;

  _PlantPainter({required this.level, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final potTop = size.height * 0.72;

    // 1. Flower Pot
    final potPaint = Paint()
      ..color = colors.ink2
      ..style = PaintingStyle.fill;
    final potPath = Path()
      ..moveTo(cx - 24, potTop)
      ..lineTo(cx + 24, potTop)
      ..lineTo(cx + 18, size.height - 10)
      ..lineTo(cx - 18, size.height - 10)
      ..close();
    canvas.drawPath(potPath, potPaint);

    final rimPaint = Paint()
      ..color = colors.ink
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTRB(cx - 28, potTop - 6, cx + 28, potTop), rimPaint);

    // 2. Stem
    final stemPaint = Paint()
      ..color = colors.accent3
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final stemPath = Path()
      ..moveTo(cx, potTop - 6)
      ..quadraticBezierTo(cx - 10, potTop - 40, cx, potTop - 70);
    canvas.drawPath(stemPath, stemPaint);

    // 3. Leaves & Flowers based on level
    final leafPaint = Paint()
      ..color = colors.accent3
      ..style = PaintingStyle.fill;

    if (level >= 1) {
      // Left leaf
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx - 14, potTop - 35), width: 18, height: 10),
        leafPaint,
      );
    }
    if (level >= 2) {
      // Right leaf
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx + 14, potTop - 50), width: 20, height: 11),
        leafPaint,
      );
    }
    if (level >= 3) {
      // Flower Bud
      final budPaint = Paint()..color = colors.accent;
      canvas.drawCircle(Offset(cx, potTop - 74), 7, budPaint);
    }
    if (level >= 4) {
      // Blooming Flowers
      final flowerPaint = Paint()..color = colors.accent2;
      for (int i = 0; i < 5; i++) {
        final double angle = (i * 72) * math.pi / 180;
        final dx = cx + 10 * math.cos(angle);
        final dy = (potTop - 74) + 10 * math.sin(angle);
        canvas.drawCircle(Offset(dx, dy), 5, flowerPaint);
      }
      canvas.drawCircle(Offset(cx, potTop - 74), 4, Paint()..color = colors.paper);
    }
  }

  @override
  bool shouldRepaint(covariant _PlantPainter oldDelegate) =>
      oldDelegate.level != level || oldDelegate.colors.mode != colors.mode;
}

/// 9. Study Streak Grass Grid (182 days: 26 cols x 7 rows)
class CabinetStreakGrid extends StatelessWidget {
  final List<int> streakLevels; // level 0..4 for 182 days
  final CabinetColors colors;

  const CabinetStreakGrid({
    super.key,
    required this.streakLevels,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final theme = CabinetTheme(colors);
    final count = streakLevels.where((l) => l > 0).length;

    return CabinetPaperCard(
      colors: colors,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('STUDY STREAK · 182 DAYS', style: theme.labelMono),
              Text('$count ACTIVE DAYS', style: theme.labelMono.copyWith(color: colors.accent)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 90,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              scrollDirection: Axis.horizontal,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 3,
                crossAxisSpacing: 3,
              ),
              itemCount: 182,
              itemBuilder: (context, index) {
                final lvl = index < streakLevels.length ? streakLevels[index] : 0;
                Color cellColor;
                if (lvl == 0) {
                  cellColor = colors.inkLine.withOpacity(0.12);
                } else if (lvl == 1) {
                  cellColor = colors.accent3.withOpacity(0.35);
                } else if (lvl == 2) {
                  cellColor = colors.accent3.withOpacity(0.55);
                } else if (lvl == 3) {
                  cellColor = colors.accent3.withOpacity(0.8);
                } else {
                  cellColor = colors.accent3;
                }

                return Container(
                  decoration: BoxDecoration(
                    color: cellColor,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Less', style: theme.labelMono.copyWith(fontSize: 9)),
              const SizedBox(width: 4),
              ...List.generate(5, (i) {
                Color c = i == 0
                    ? colors.inkLine.withOpacity(0.12)
                    : colors.accent3.withOpacity(0.25 * i);
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(1)),
                );
              }),
              const SizedBox(width: 4),
              Text('More', style: theme.labelMono.copyWith(fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }
}
