import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/cabinet_colors.dart';
import '../../core/theme/cabinet_theme.dart';
import '../../core/utils/format_count.dart' as format_util;

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
                    Text(catalogNo, style: theme.catalogNo),
                    if (tag != null && tag!.isNotEmpty)
                      Text(
                        tag!.toUpperCase(),
                        style: theme.labelMono.copyWith(fontSize: 9),
                      ),
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
/// 레벨이 오르면 도장 슬램 축하 애니메이션을 재생한다 (첫 빌드는 기준선이라 재생 안 함).
class CabinetWordGarden extends StatefulWidget {
  final CabinetColors colors;
  final int totalCount;
  final int masteredCount;

  /// 레벨이 상승해 축하 애니메이션이 발동될 때 호출 (화면 전체 축하 연출용)
  final void Function(int level)? onLevelUp;

  static const int maxGardenLevel = 20;
  static const int maxGardenWords = 2000;

  const CabinetWordGarden({
    super.key,
    required this.colors,
    this.totalCount = 0,
    this.masteredCount = 0,
    this.onLevelUp,
  });

  /// 축하 강조(마일스톤) 레벨: 1(첫 싹), 5/10/15(개화), 20(마스터)
  static bool isMilestoneLevel(int level) =>
      level == 1 || level == maxGardenLevel || level % 5 == 0;

  /// 레벨 n (n>=1) 도달에 필요한 최소 단어 수: 5 * n^2
  static int _wordsForLevel(int n) => 5 * n * n;

  /// 단어 수 → 정원 레벨 (0~20). 임계값: 5 * n^2
  static int levelForWordCount(int totalCount) {
    for (var i = maxGardenLevel; i >= 1; i--) {
      if (totalCount >= _wordsForLevel(i)) return i;
    }
    return 0;
  }

  /// 레벨에 도달하는 데 필요한 최소 단어 수
  static int thresholdForLevel(int level) {
    if (level <= 0) return 0;
    if (level >= maxGardenLevel) return maxGardenWords;
    return _wordsForLevel(level);
  }

  /// 화분 성장 지오메트리 (테스트용 공개 헬퍼).
  /// 레벨이 오를수록 화분이 커져야 한다: potTop(위쪽 y)이 작아지고
  /// 상단 반폭·높이가 커진다. [_PlantPainter]와 동일한 공식.
  /// [potScale]은 레벨업 성장 연출로, 0~1이면 화분이 작게 시작한다.
  /// 식물이 화분에 붙어 있으려면 potTop이 스케일된 높이에서 유도되어야 한다.
  static ({double potTop, double topWidth, double bottomWidth, double height})
      potGeometryForLevel(int level, {double potScale = 1.0}) {
    final p = (level / maxGardenLevel).clamp(0.0, 1.0);
    final g = Curves.easeInOut.transform(p);
    final topWidth = (28 + 8 * g) * potScale;
    final bottomWidth = (21 + 6 * g) * potScale;
    final height = (34 + 18 * g) * potScale;
    final potTop = 150 - 8 - height; // 캔버스 150 기준 바닥 고정
    return (
      potTop: potTop,
      topWidth: topWidth,
      bottomWidth: bottomWidth,
      height: height,
    );
  }

  /// 꽃/봉오리 배치 레이아웃 (테스트용 공개 헬퍼). [_PlantPainter]와 동일.
  /// 각 항목: [세로 위치(줄기 상대 높이 0~1), 좌우 오프셋, 색 인덱스].
  /// 줄기 상단(작은 값)부터 중·하단까지 계단식으로 배치된다.
  static List<(double, double, int)> get flowerLayout => const [
        (0.02, -14.0, 0), // 왕관 부근 (가장 위)
        (0.16, 13.0, 1),
        (0.28, -16.0, 2),
        (0.40, 18.0, 3),
        (0.52, -20.0, 0),
        (0.63, 21.0, 1),
        (0.74, -18.0, 2),
        (0.86, 14.0, 3), // 줄기 중·하단
      ];

  /// 각 꽃 위치가 '꽃'으로 피는 progress 임계값 (위→아래 순차 개화).
  /// [_PlantPainter]의 bloomAt과 동일.
  static List<double> get bloomAtProgress => const [
        0.50, 0.58, 0.64, 0.72, 0.78, 0.86, 0.92, 0.98,
      ];

  @override
  State<CabinetWordGarden> createState() => _CabinetWordGardenState();
}

class _CabinetWordGardenState extends State<CabinetWordGarden>
    with TickerProviderStateMixin {
  late final AnimationController _stampController;
  late final Animation<double> _slam; // 도장 '퍽' (0→1, easeOutBack 오버슈트)
  late final Animation<double> _pop; // 식물 펑 (0→1→0)

  /// 개화 애니메이션: 레벨업 시 새로 핀 꽃들이 봉오리→꽃으로 펼쳐진다.
  late final AnimationController _bloomController;

  /// 이번 개화 애니메이션 대상 꽃 위치 (tier 인덱스).
  /// 레벨업 시 '새로 핀 tier'만 담고, 애니메이션이 끝나면 비운다.
  /// (이전에 핀 꽃이 반복 재생되지 않도록)
  final Set<int> _bloomingTiers = {};

  int _prevLevel = 0;

  @override
  void initState() {
    super.initState();
    _stampController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _slam = CurvedAnimation(
      parent: _stampController,
      curve: const Interval(0.0, 0.28, curve: Curves.easeOutBack),
    );
    _pop = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 75,
      ),
    ]).animate(_stampController);
    _bloomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _prevLevel = CabinetWordGarden.levelForWordCount(widget.totalCount);
  }

  /// 새 레벨에서 개화가 시작되는 꽃 위치(tier)를 계산한다.
  /// bloomAt 임계값을 새로 넘은 위치만 애니메이션 대상.
  static Set<int> _tiersBloomingAt(int newLevel) {
    final p = (newLevel / CabinetWordGarden.maxGardenLevel).clamp(0.0, 1.0);
    final blooms = CabinetWordGarden.bloomAtProgress;
    final tiers = <int>{};
    for (var i = 0; i < blooms.length; i++) {
      if (p >= blooms[i]) tiers.add(i);
    }
    return tiers;
  }

  @override
  void didUpdateWidget(covariant CabinetWordGarden oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.totalCount == widget.totalCount) return;
    final newLevel = CabinetWordGarden.levelForWordCount(widget.totalCount);
    if (newLevel > _prevLevel) {
      _stampController.forward(from: 0);
      // 새로 핀 꽃 위치를 이전 레벨 대비로 계산해 개화 애니메이션 재생.
      // 이전 회차 tier는 비우고 당회차만 담는다 (반복 재생 방지).
      final newlyBloomed =
          _tiersBloomingAt(newLevel).difference(_tiersBloomingAt(_prevLevel));
      if (newlyBloomed.isNotEmpty) {
        _bloomingTiers
          ..clear()
          ..addAll(newlyBloomed);
        _bloomController.forward(from: 0);
      }
      // didUpdateWidget은 빌드 중에 호출되므로, 콜백(setState 포함 가능)은 프레임 뒤로 미룬다.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onLevelUp?.call(newLevel);
      });
    }
    _prevLevel = newLevel;
  }

  @override
  void dispose() {
    _stampController.dispose();
    _bloomController.dispose();
    super.dispose();
  }

  String _stampTextForLevel(int level) {
    if (level >= CabinetWordGarden.maxGardenLevel) return 'MASTER GARDEN ✨';
    if (level == 1) return 'SPROUTED!';
    if (level % 5 == 0) return 'BLOOMED!';
    return 'LEVEL UP';
  }

  @override
  Widget build(BuildContext context) {
    final theme = CabinetTheme(widget.colors);
    final level = CabinetWordGarden.levelForWordCount(widget.totalCount);
    final currentMin = CabinetWordGarden.thresholdForLevel(level);
    final nextMin = CabinetWordGarden.thresholdForLevel(level + 1);
    final remaining = level < CabinetWordGarden.maxGardenLevel
        ? (nextMin - widget.totalCount)
        : 0;
    final progress = level >= CabinetWordGarden.maxGardenLevel
        ? 1.0
        : ((widget.totalCount - currentMin) / (nextMin - currentMin)).clamp(
            0.0,
            1.0,
          );

    String statusText;
    if (level >= CabinetWordGarden.maxGardenLevel) {
      statusText = 'Master Botanical Garden! ✨🌸';
    } else if (level >= CabinetWordGarden.maxGardenLevel - 2) {
      statusText = 'Garden Fully Bloomed! 🌸 ($remaining words to Master)';
    } else {
      statusText =
          'Next bloom in $remaining words (${widget.masteredCount} Mastered)';
    }

    return CabinetPaperCard(
      colors: widget.colors,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // flex:1 (loose) — 좁은 카드에서도 라벨이 줄어들고 ellipsis 처리되어
              // LVL 표시가 밀려 넘치지 않는다. 넓은 카드에선 자연 크기로 그대로 표시.
              Flexible(
                flex: 1,
                child: Text(
                  'SECTION · WORD GARDEN',
                  style: theme.labelMono,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'LVL $level / ${CabinetWordGarden.maxGardenLevel}',
                style: theme.labelMono.copyWith(color: widget.colors.accent),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: SizedBox(
              width: 150,
              height: 150,
              child: AnimatedBuilder(
                animation: Listenable.merge([_stampController, _bloomController]),
                builder: (context, child) {                  final popScale = 1.0 + 0.06 * _pop.value;
                  // StackFit.expand: 자식 CustomPaint에 딱 맞는(150x150) 제약을 전달해
                  // 느슨한 제약으로 인한 0×0 렌더링을 방지한다.
                  return Stack(
                    fit: StackFit.expand,
                    clipBehavior: Clip.none,
                    children: [
                      Transform.scale(scale: popScale, child: child),
                      if (_stampController.isAnimating) _buildStampOverlay(level),
                    ],
                  );
                },
                child: CustomPaint(
                  painter: _PlantPainter(
                    level: level,
                    maxLevel: CabinetWordGarden.maxGardenLevel,
                    colors: widget.colors,
                    bloomValue: _bloomController.value,
                    bloomTiers: _bloomingTiers,
                    // 레벨업 성장: 개화 애니메이션 구간 동안 화분이 팡! 커진다.
                    // (easeOutBack 오버슈트로 살짝 크게 튀었다가 자리잡음)
                    potScale: _bloomController.isAnimating
                        ? 0.82 +
                            0.18 *
                                Curves.easeOutBack.transform(_bloomController.value)
                        : 1.0,
                    // 만개 스페셜: 최종 레벨일 때 모든 꽃 동시 개화 + 황금 연출
                    isFullBloom: level >= CabinetWordGarden.maxGardenLevel,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(statusText, style: theme.handNote.copyWith(fontSize: 16)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: widget.colors.inkLine,
              valueColor: AlwaysStoppedAnimation<Color>(widget.colors.accent3),
            ),
          ),
        ],
      ),
    );
  }

  /// 레벨업 도장: 크게 떠서 '퍽' 찍히고 잠시 후 사라진다.
  /// 마일스톤 레벨(1/5/10/15/20)은 더 크게 + 전용 문구.
  /// 매 프레임 리빌드되는 바깥 AnimatedBuilder 안에서 호출되므로,
  /// 여기서는 컨트롤러 값을 직접 읽어 계산한다 (중첩 리빌드 방지).
  Widget _buildStampOverlay(int level) {
    final milestone = CabinetWordGarden.isMilestoneLevel(level);
    final startScale = milestone ? 2.2 : 2.0;
    final rotateDeg = milestone ? -9.0 : -6.0;
    final t = _stampController.value;
    final scale = startScale - (startScale - 1.0) * _slam.value;
    final opacity = t < 0.55 ? 1.0 : (1.0 - (t - 0.55) / 0.45).clamp(0.0, 1.0);

    return Positioned(
      left: 0,
      right: 0,
      top: 8,
      child: Center(
        child: Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: Transform.rotate(
              angle: rotateDeg * math.pi / 180,
              child: CabinetStamp(
                text: _stampTextForLevel(level),
                color: milestone ? widget.colors.accent : widget.colors.accent2,
                rotateDegrees: 0,
                fontSize: milestone ? 12.0 : 10.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 레벨(0~20)에 따라 화분→씨앗→줄기→잎→가지→봉오리→꽃→만개로 점진적 성장을 그린다.
/// 줄기 높이/굵기, 잎 개수·크기, 꽃 개수 모두 progress(=level/maxLevel)에 연동된다.
class _PlantPainter extends CustomPainter {
  final int level;
  final int maxLevel;
  final CabinetColors colors;

  /// 개화 애니메이션 값 0~1. 1이면 모든 꽃이 활짝 (정지 상태).
  final double bloomValue;

  /// 현재 개화 애니메이션 중인 꽃 위치(tier 인덱스).
  final Set<int> bloomTiers;

  /// 레벨업 성장 연출: 0~1 동안 화분이 작게 시작해 팡! 커진다 (아래 고정).
  final double potScale;

  /// 만개(최종 레벨) 스페셜 시퀀스 여부: 모든 꽃 동시 개화 + 황금 고리.
  final bool isFullBloom;

  _PlantPainter({
    required this.level,
    required this.maxLevel,
    required this.colors,
    this.bloomValue = 1.0,
    this.bloomTiers = const <int>{},
    this.potScale = 1.0,
    this.isFullBloom = false,
  });

  // ── 테라코타 팔레트 (실제 점토 토분) ──────────────────────────────
  // 모든 테마에서 동일한 주황 점토색을 사용하고, mono 테마만
  // 그레이스케일로 바꿔 최소주의 컨셉을 유지한다.
  static const Color _tBodyTop = Color(0xFFE7A87F); // 위쪽 (밝게)
  static const Color _tBodyMid = Color(0xFFC77A45); // 중간
  static const Color _tBodyDeep = Color(0xFFA45A2E); // 아래쪽 (어둡게)
  static const Color _tRim = Color(0xFF9E5A2E); // 림/입구 테두리
  static const Color _tOutline = Color(0xFF6E3D1E); // 실루엣 윤곽선
  static const Color _tRidge = Color(0xFF8A4A24); // 적층 홈선
  static const Color _tHighlight = Color(0xFFFFF1DE); // 림 빛 받는 면
  static const Color _tLabel = Color(0xFFF2E3CB); // 라벨 밴드
  static const Color _tSoil = Color(0xFF4A2E16); // 흙

  /// [mono]면 그레이스케일 (명도만 유지). 그 외엔 원색.
  static Color _terracotta(Color color, bool mono) {
    if (!mono) return color;
    // 인지 명도 기반 그레이 (BT.601 가중치)
    final l = (0.299 * color.r + 0.587 * color.g + 0.114 * color.b)
        .clamp(0.0, 1.0);
    return Color.fromRGBO(
      (l * 255).round(),
      (l * 255).round(),
      (l * 255).round(),
      color.a,
    );
  }

  bool get _monoMode => colors.mode == CabinetThemeMode.mono;

  Color get _bodyTop => _terracotta(_tBodyTop, _monoMode);
  Color get _bodyMid => _terracotta(_tBodyMid, _monoMode);
  Color get _bodyDeep => _terracotta(_tBodyDeep, _monoMode);
  Color get _rim => _terracotta(_tRim, _monoMode);
  Color get _outline => _terracotta(_tOutline, _monoMode);
  Color get _ridge => _terracotta(_tRidge, _monoMode);
  Color get _highlight => _terracotta(_tHighlight, _monoMode);
  Color get _label => _terracotta(_tLabel, _monoMode);
  Color get _soil => _terracotta(_tSoil, _monoMode);
  Color get _stem => _terracotta(_tRidge, _monoMode);


  /// 성장 비율 0~1 (레벨/최대레벨). [level]/[maxLevel]에서 유도되는 순수 값.
  double get progress => (level / maxLevel).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final progress = this.progress;
    final bv = bloomValue; // 개화/성장 애니메이션 값

    // ── 화분 성장 지오메트리 ─────────────────────────────────────────
    // progress(0~1)에 따라 묘종→중형→대형 토분으로 성장하고,
    // potScale(0~1)은 레벨업 순간 '팡! 커지는' 성장 연출로 곱해진다.
    // 모든 지오메트리에 직접 적용해 화분과 식물이 항상 함께 붙어 있다.
    final potGrowth = Curves.easeInOut.transform(progress);
    final potTopW = (28 + 8 * potGrowth) * potScale; // 28..36
    final potBotW = (21 + 6 * potGrowth) * potScale; // 21..27
    final potH = (34 + 18 * potGrowth) * potScale; // 34..52
    final potRimW = potTopW + (4 + 2 * potGrowth) * potScale; // 32..42
    final potRimH = 7.0 * potScale; // 림 높이
    final ridgeCount = (3 + potGrowth).round(); // 3..4 홈선
    final potTop = size.height - 8 - potH; // 바닥 고정, 위로 성장
    final potBottom = size.height - 8;
    final potRimTop = potTop - potRimH;

    // 1. 바닥 그림자 (화분이 놓인 면, 화분 폭에 비례)
    final groundShadow = Paint()
      ..color = _outline.withValues(alpha: 0.28);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, size.height - 6),
        width: (74 + 14 * potGrowth) * potScale,
        height: 10,
      ),
      groundShadow,
    );

    // 2. 화분 본체: 위→아래 그라데이션 (테라코타 토분)
    final potPath = Path()
      ..moveTo(cx - potTopW, potTop)
      ..lineTo(cx + potTopW, potTop)
      ..lineTo(cx + potBotW, potBottom)
      ..lineTo(cx - potBotW, potBottom)
      ..close();
    final potPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_bodyTop, _bodyMid, _bodyDeep],
      ).createShader(
        // 본체 경계에 맞춰 3단 그라데이션이 온전히 보이게
        Rect.fromLTRB(cx - potRimW, potTop, cx + potRimW, potBottom),
      );
    canvas.drawPath(potPath, potPaint);
    // 실루엣 윤곽선
    canvas.drawPath(
      potPath,
      Paint()
        ..color = _outline.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // 3. 토분 질감: 클레이 적층 홈선 (화분 경사를 따라 좁아짐)
    final ridgePaint = Paint()
      ..color = _ridge.withValues(alpha: 0.4)
      ..strokeWidth = 1.2;
    for (int i = 1; i <= ridgeCount; i++) {
      final t = i / (ridgeCount + 1);
      final y = potTop + potH * t;
      final halfW = potTopW - (y - potTop) * (potTopW - potBotW) / potH;
      canvas.drawLine(Offset(cx - halfW, y), Offset(cx + halfW, y), ridgePaint);
    }

    // 4. 림 (입구 테두리) + 윗면 하이라이트
    final rimRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(cx - potRimW, potRimTop, cx + potRimW, potTop),
      const Radius.circular(2),
    );
    canvas.drawRRect(rimRect, Paint()..color = _rim);
    canvas.drawRRect(
      rimRect,
      Paint()
        ..color = _outline.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // 5. 흙 (화분 입구 안쪽)
    final soilPaint = Paint()
      ..color = _soil.withValues(alpha: 0.72);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, potTop - 2),
        width: potTopW * 1.7,
        height: 8,
      ),
      soilPaint,
    );

    // 4b. 림 윗면 하이라이트 (흙보다 위에 그려 연속된 빛 가장자리로)
    final rimHighlight = Paint()
      ..color = _highlight.withValues(alpha: 0.5)
      ..strokeWidth = 1.6;
    canvas.drawLine(
      Offset(cx - (potRimW - 2.5), potRimTop + 1),
      Offset(cx + (potRimW - 2.5), potRimTop + 1),
      rimHighlight,
    );

    // 6. 라벨 밴드 (크림색 장식 가로줄, 화분 높이에 비례)
    final linePaint = Paint()
      ..color = _label.withValues(alpha: 0.75)
      ..strokeWidth = 1.5;
    final labelY = potTop + potH * 0.2;
    canvas.drawLine(
      Offset(cx - (potTopW - 2), labelY),
      Offset(cx + (potTopW - 2), labelY),
      linePaint,
    );

    // 줄기 성장 변수 (화분이 커지는 만큼 식물도 함께)
    final stemHeight = 22 + 40 * potGrowth; // 22..62
    final stemTopY = potTop - 8 - stemHeight;
    final stemBaseY = potTop - 4;

    // 레벨 0: 흙 위에 씨앗만
    if (level <= 0) {
      canvas.drawCircle(
        Offset(cx, potTop - 5),
        4.0,
        Paint()..color = colors.accent3,
      );
      return;
    }

    // 7. 줄기 (주경 + 측경). 성장에 따라 측경이 추가된다.
    final stemPaint = Paint()
      ..color = _stem
      ..strokeWidth = 2.5 + 2.0 * progress
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // 주경: 살짝 휘어진 메인 줄기
    final mainStemPath = Path()
      ..moveTo(cx, stemBaseY)
      ..quadraticBezierTo(
        cx - 6 * potGrowth,
        stemBaseY - stemHeight * 0.55,
        cx,
        stemTopY,
      );
    canvas.drawPath(mainStemPath, stemPaint);

    // 8. 측경 (중반 이후부터 좌우로 뻗는 보조 줄기, 끝에 꽃)
    final hasBranches = progress >= 0.45;
    final leftBranchTip = Offset(
      cx - 26,
      stemBaseY - stemHeight * 0.9,
    );
    final rightBranchTip = Offset(
      cx + 26,
      stemBaseY - stemHeight * 0.8,
    );
    if (hasBranches) {
      final leftBranch = Path()
        ..moveTo(cx - 2, stemBaseY - stemHeight * 0.5)
        ..quadraticBezierTo(
          cx - 22,
          stemBaseY - stemHeight * 0.62,
          leftBranchTip.dx,
          leftBranchTip.dy,
        );
      canvas.drawPath(leftBranch, stemPaint..strokeWidth = 2.2);

      final rightBranch = Path()
        ..moveTo(cx + 2, stemBaseY - stemHeight * 0.4)
        ..quadraticBezierTo(
          cx + 22,
          stemBaseY - stemHeight * 0.52,
          rightBranchTip.dx,
          rightBranchTip.dy,
        );
      canvas.drawPath(rightBranch, stemPaint..strokeWidth = 2.2);
    }

    // 9. 잎 (레벨에 따라 개수·크기 증가)
    final leafPaint = Paint()
      ..color = colors.accent3
      ..style = PaintingStyle.fill;
    final leafPairs = (progress * 9).round(); // 0..9쌍 (양쪽 18장)
    final leafScale = 0.7 + 0.7 * progress;
    for (int i = 0; i < leafPairs; i++) {
      final t = (i + 1) / (leafPairs + 1);
      final y = stemBaseY - stemHeight * t;
      final xOff = 13 + 10 * progress;
      final isLeft = i.isEven;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx + (isLeft ? -xOff : xOff), y + 4),
          width: 16 * leafScale,
          height: 9 * leafScale,
        ),
        leafPaint,
      );
    }

    // ── 10. 꽃·봉오리: 줄기 전체 높이에 고르게 분포 ──────────────────
    // 줄기 상단부터 중·하단까지 8개 위치(계단식 좌우 교차)에 배치.
    // 봉오리는 꽃이 피기 전 단계로, 아직 피지 않은 위치에 그려진다.
    final flowerColors = [
      colors.accent,
      colors.accent2,
      colors.tapeYellow,
      colors.tapePink,
    ];
    final flowerLayout = CabinetWordGarden.flowerLayout;
    final bloomAt = CabinetWordGarden.bloomAtProgress;
    final budPaint = Paint()..color = colors.accent3;
    final budTipPaint = Paint()..color = colors.accent;
    for (int i = 0; i < flowerLayout.length; i++) {
      final (fracY, xOff, colorIdx) = flowerLayout[i];
      final y = stemBaseY - stemHeight * fracY;
      final pos = Offset(cx + xOff, y);
      final isBloom = progress >= bloomAt[i];
      if (!isBloom) {
        // 봉오리: 작은 꽃자루 + 타원 봉오리 (아직 피지 않은 단계)
        canvas.drawLine(
          pos,
          Offset(pos.dx, pos.dy - 5),
          Paint()
            ..color = _stem
            ..strokeWidth = 1.4
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: pos,
            width: 6.5,
            height: 8.5,
          ),
          budPaint,
        );
        canvas.drawCircle(pos.translate(0, -1), 2.2, budTipPaint);
      } else {
        // 꽃: 위치에 따라 크기·꽃잎 수를 다르게 (아래로 갈수록 작고 단순)
        final size = 7.4 - i * 0.55;
        final petalCount = (6 + progress * 6).round() - i ~/ 2;
        // 개화 애니메이션: 새로 핀 위치는 봉오리→꽃으로 펼쳐진다.
        // 위에서부터 순차적으로(stagger) 펼쳐진다.
        final isAnimating = bloomTiers.contains(i);
        if (isAnimating && bloomValue < 1.0) {
          // 만개 스페셜: 모든 꽃이 동시에 펼쳐진다 (stagger 없음)
          final stagger = isFullBloom ? 0.0 : 0.10 * i;
          final t =
              ((bloomValue - stagger) / (1.0 - stagger)).clamp(0.0, 1.0);
          if (t <= 0) {
            // 아직 펼쳐지기 전: 봉오리 상태 유지
            canvas.drawLine(
              pos,
              Offset(pos.dx, pos.dy - 5),
              Paint()
                ..color = _stem
                ..strokeWidth = 1.4
                ..strokeCap = StrokeCap.round,
            );
            canvas.drawOval(
              Rect.fromCenter(center: pos, width: 6.5, height: 8.5),
              budPaint,
            );
            canvas.drawCircle(pos.translate(0, -1), 2.2, budTipPaint);
          } else {
            // 개화 중: 작은 봉오리 색에서 꽃 색으로 바뀌며 꽃잎이 펼쳐진다.
            final open = Curves.easeOutBack.transform(t);
            final scale = 0.25 + 0.75 * open;
            final petalColor = Color.lerp(
              colors.accent3,
              flowerColors[colorIdx],
              t,
            )!;
            drawFlower(
              canvas,
              pos,
              size * scale,
              petalColor,
              petalCount: isFullBloom
                  ? (6 + progress * 6).round() // 만개: 전부 최대 꽃잎
                  : petalCount,
              openFactor: open,
            );
            // 꽃가루 이펙트: 개화 중 꽃 주위로 금색 입자가 흩날린다
            _drawPollen(canvas, pos, i, bv);
          }
        } else {
          drawFlower(
            canvas,
            pos,
            size,
            flowerColors[colorIdx],
            petalCount: isFullBloom
                ? (6 + progress * 6).round()
                : petalCount,
          );
        }
      }
    }

    // 11. 측경 끝 꽃 (레벨이 높을수록 많이)
    if (hasBranches) {
      if (level >= 10) {
        drawFlower(canvas, leftBranchTip, 6.5, flowerColors[2],
            petalCount: (6 + progress * 6).round());
      } else if (level >= 6) {
        // 아직 피지 않았다면 봉오리로 표시
        canvas.drawOval(
          Rect.fromCenter(center: leftBranchTip, width: 6, height: 8),
          budPaint,
        );
        canvas.drawCircle(leftBranchTip.translate(0, -1), 2, budTipPaint);
      }
      if (level >= 14) {
        drawFlower(canvas, rightBranchTip, 6.5, flowerColors[3],
            petalCount: (6 + progress * 6).round());
      } else if (level >= 10) {
        canvas.drawOval(
          Rect.fromCenter(center: rightBranchTip, width: 6, height: 8),
          budPaint,
        );
        canvas.drawCircle(rightBranchTip.translate(0, -1), 2, budTipPaint);
      }
    }

    // 12. 만개 (최종 레벨: 왕관 꽃 + 반짝이 + 만개 스페셜)
    if (level >= maxLevel) {
      final crown = Offset(cx, stemTopY + 2);
      // 만개 스페셜: 황금 고리가 왕관 주위로 퍼지며 사라진다
      if (isFullBloom && bv < 1.0) {
        final ringT = Curves.easeOut.transform(bv);
        final ringRadius = 8 + 34 * ringT;
        canvas.drawCircle(
          crown,
          ringRadius,
          Paint()
            ..color = colors.accent2.withValues(alpha: 0.55 * (1 - ringT))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2,
        );
        canvas.drawCircle(
          crown,
          ringRadius * 0.55,
          Paint()
            ..color = colors.accent.withValues(alpha: 0.35 * (1 - ringT))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
        // 왕관 주위 황금 꽃가루 폭발
        for (int p = 0; p < 12; p++) {
          final a = p * math.pi / 6;
          final d = 10 + 26 * ringT;
          canvas.drawCircle(
            Offset(
              crown.dx + math.cos(a) * d,
              crown.dy + math.sin(a) * d,
            ),
            1.8,
            Paint()
              ..color = colors.accent2.withValues(alpha: 0.8 * (1 - ringT)),
          );
        }
      }
      drawFlower(
        canvas,
        crown,
        isFullBloom ? 11.0 : 9.5,
        colors.tapePink,
        petalCount: (6 + progress * 6).round(),
      );
      final sparkPaint = Paint()..color = colors.accent;
      canvas.drawCircle(Offset(cx - 30, stemTopY + 8), 2.5, sparkPaint);
      canvas.drawCircle(Offset(cx + 32, stemTopY + 4), 2.0, sparkPaint);
      canvas.drawCircle(Offset(cx - 14, stemTopY - 6), 2.0, sparkPaint);
      canvas.drawCircle(Offset(cx + 18, stemTopY - 8), 2.5, sparkPaint);
      canvas.drawCircle(Offset(cx + 2, stemTopY - 10), 2.0, sparkPaint);
    }
  }

  /// 꽃가루 이펙트: 개화 중(t 0.15~0.8) 꽃 주위로 금색 입자가 방사형으로 흩날린다.
  /// tier별로 개수·거리·속도가 다르게 결정적(deterministic) 생성된다.
  void _drawPollen(Canvas canvas, Offset flowerPos, int tier, double bv) {
    final t = ((bv - 0.15) / 0.65).clamp(0.0, 1.0);
    if (t <= 0 || t >= 1) return;
    final count = isFullBloom ? 8 : 5;
    final pollenPaint = Paint()..color = colors.accent2;
    for (int p = 0; p < count; p++) {
      final a = (p / count) * math.pi * 2 + tier * 0.9; // tier마다 각도 어긋남
      final dist = (6 + ((tier * 3 + p * 7) % 14)) * t;
      final size = 0.8 + ((p + tier) % 3) * 0.5;
      canvas.drawCircle(
        Offset(
          flowerPos.dx + math.cos(a) * dist,
          flowerPos.dy + math.sin(a) * dist,
        ),
        size,
        pollenPaint,
      );
    }
  }

  void drawFlower(
    Canvas canvas,
    Offset center,
    double size,
    Color petalColor, {
    int? petalCount,
    double openFactor = 1.0,
  }) {
    // 성장에 따라 꽃잎 수가 6→12개로 증가 (만개로 갈수록 풍성하게)
    final petals = petalCount ?? (6 + progress * 6).round();
    // 개화 중엔 꽃잎이 안쪽(반지름 작음)에서 밖으로 펼쳐진다.
    final petalRadius = size * 0.8 * (0.5 + 0.5 * openFactor);
    final petalSize = size * 0.55 * (0.4 + 0.6 * openFactor);
    final pPaint = Paint()..color = petalColor;
    for (int i = 0; i < petals; i++) {
      final double angle = i * (360 / petals) * math.pi / 180;
      final dx = center.dx + petalRadius * math.cos(angle);
      final dy = center.dy + petalRadius * math.sin(angle);
      canvas.drawCircle(Offset(dx, dy), petalSize, pPaint);
    }
    canvas.drawCircle(center, size * 0.5, Paint()..color = colors.paper3);
    canvas.drawCircle(center, size * 0.25, Paint()..color = colors.paper);
  }

  @override
  bool shouldRepaint(covariant _PlantPainter oldDelegate) =>
      oldDelegate.level != level ||
      oldDelegate.bloomValue != bloomValue ||
      oldDelegate.potScale != potScale ||
      oldDelegate.isFullBloom != isFullBloom ||
      oldDelegate.bloomTiers.length != bloomTiers.length ||
      bloomTiers.difference(oldDelegate.bloomTiers).isNotEmpty ||
      oldDelegate.colors.mode != colors.mode;
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
              Text(
                '$count ACTIVE DAYS',
                style: theme.labelMono.copyWith(color: colors.accent),
              ),
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
                final lvl = index < streakLevels.length
                    ? streakLevels[index]
                    : 0;
                Color cellColor;
                if (lvl == 0) {
                  cellColor = colors.inkLine.withValues(alpha: 0.12);
                } else if (lvl == 1) {
                  cellColor = colors.accent3.withValues(alpha: 0.35);
                } else if (lvl == 2) {
                  cellColor = colors.accent3.withValues(alpha: 0.55);
                } else if (lvl == 3) {
                  cellColor = colors.accent3.withValues(alpha: 0.8);
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
                    ? colors.inkLine.withValues(alpha: 0.12)
                    : colors.accent3.withValues(alpha: 0.25 * i);
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(1),
                  ),
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

/// 10. 마스터 정원 기념 배지 카드 (레벨 20 달성 시 영구 표시)
/// [achievedDate]가 null이면 잠금 상태, 값이 있으면 해금(달성 날짜 표시) 상태.
/// 미해금 상태에서 [currentCount]/[thresholdCount]를 주면
/// 배지 원에 진행 링 + '1,500 / 2,000단어' 진행 텍스트가 표시된다.
class CabinetBadgeCard extends StatelessWidget {
  final String? achievedDate;
  final CabinetColors colors;

  /// 탭 시 수료증/업적 화면으로 이동 (대시보드에서 연결).
  final VoidCallback? onTap;

  /// 현재 수집 단어 수 (진행 링·텍스트 표시용). 해금 상태면 무시.
  final int currentCount;

  /// 목표 단어 수 (기본: 마스터 정원 2,000).
  final int thresholdCount;

  const CabinetBadgeCard({
    super.key,
    required this.achievedDate,
    required this.colors,
    this.onTap,
    this.currentCount = 0,
    this.thresholdCount = 2000,
  });

  @override
  Widget build(BuildContext context) {
    final theme = CabinetTheme(colors);
    final isEarned = achievedDate != null;
    // 진행 데이터가 없으면(임계값 0 이하) 링/텍스트를 숨긴다.
    final hasProgress = thresholdCount > 0;
    final progress = hasProgress
        ? (currentCount / thresholdCount).clamp(0.0, 1.0)
        : 0.0;

    return CabinetPaperCard(
      colors: colors,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          // 배지 원: 해금 시 컬러 + 트로피, 미해금 시 실루엣 + 진행 링 + 잠금 뱃지
          // (업적 컬렉션 배지와 동일한 잠금 스타일)
          SizedBox(
            width: 46,
            height: 46,
            child: Stack(
              // 음수 오프셋 잠금 뱃지가 1px 밀착되도록 클리핑 없이 허용
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isEarned ? colors.accent : colors.paper3,
                    border: Border.all(
                      color: isEarned ? colors.ink : colors.inkLineStrong,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.emoji_events,
                    // 미해금: 회색 실루엣 (아이콘 형태 유지)
                    color: isEarned ? colors.paper : colors.inkLineStrong,
                    size: 22,
                  ),
                ),
                // 미해금: 진행 링 (단계별 색상)
                if (!isEarned && hasProgress)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 3,
                        strokeCap: StrokeCap.round,
                        backgroundColor: colors.inkLine,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colors.progressHeat(progress),
                        ),
                      ),
                    ),
                  ),
                if (!isEarned)
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: CabinetLockBadge(
                      colors: colors,
                      diameter: 17,
                      iconSize: 10,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEarned ? 'MASTER GARDENER ✨' : 'MASTER GARDENER',
                  style: theme.labelMono.copyWith(
                    color: isEarned ? colors.accent : colors.ink3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isEarned
                      ? 'Achieved $achievedDate · 2,000 words collected!'
                      : '2,000단어를 모아 레벨 20에 도달하면 잠금 해제',
                  style: theme.bodySans.copyWith(
                    fontSize: 11,
                    color: colors.ink3,
                  ),
                ),
                if (!isEarned && hasProgress) ...[
                  const SizedBox(height: 5),
                  // 진행 텍스트: 현재 / 목표 단어 수
                  Text(
                    '${format_util.formatCount(currentCount)} / ${format_util.formatCount(thresholdCount)}단어 · ${(progress * 100).round()}%',
                    style: theme.labelMono.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: colors.progressHeat(progress),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isEarned)
            Transform.rotate(
              angle: -0.12,
              child: CabinetStamp(
                text: 'ACHIEVED',
                color: colors.accent,
                fontSize: 8,
              ),
            ),
        ],
      ),
    );
  }

}

/// 11. 레벨업 축하 컨페티 오버레이 (화면 전체에서 짧게 흩날림)
/// 생성 즉시 재생되고, 애니메이션 완료 시 [onFinished]를 호출한다.
/// [big]이면 마일스톤 레벨용으로 입자 수·크기가 커진다.
class CabinetConfettiOverlay extends StatefulWidget {
  final CabinetColors colors;
  final bool big;

  /// 만개(최종 레벨) 스페셜: 시작 순간 화면 전체가 잠깐 반짝인다.
  final bool flash;
  final VoidCallback? onFinished;

  const CabinetConfettiOverlay({
    super.key,
    required this.colors,
    this.big = false,
    this.flash = false,
    this.onFinished,
  });

  @override
  State<CabinetConfettiOverlay> createState() => _CabinetConfettiOverlayState();
}

class _CabinetConfettiOverlayState extends State<CabinetConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final _ConfettiPainter _painter;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 2200),
          )
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) widget.onFinished?.call();
          })
          ..forward();

    final palette = [
      widget.colors.accent,
      widget.colors.accent2,
      widget.colors.accent3,
      widget.colors.accentBlue,
      widget.colors.tapeYellow,
      widget.colors.tapePink,
      widget.colors.tapeBlue,
      widget.colors.tapeGreen,
      widget.colors.paperEdge,
    ];
    _painter = _ConfettiPainter(
      controller: _controller,
      palette: palette,
      count: widget.big ? 90 : 50,
      scale: widget.big ? 1.4 : 1.0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final child = CustomPaint(
          painter: _painter,
          child: const SizedBox.expand(),
        );
        if (!widget.flash) return child;
        // 만개 플래시: 시작 0.3초 동안 화면 전체가 잠깐 반짝인다.
        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            CustomPaint(
              painter: _FlashPainter(
                t: _controller.value,
                color: widget.colors.mode == CabinetThemeMode.mono
                    ? const Color(0xFFE8E8E8)
                    : const Color(0xFFFFF3D6),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 만개 플래시 페인터: 시작(0~0.35s)에 화면 중앙에서 바깥으로 퍼지는
/// 따뜻한 빛 폭발, 이후 빠르게 사라진다.
class _FlashPainter extends CustomPainter {
  final double t; // 0~1 (컨페티 컨트롤러 값)
  final Color color;

  _FlashPainter({required this.t, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // 0.0~0.16: 반짝 (가장 밝게), 0.16~0.35: 페이드아웃, 이후: 없음
    final fade = t < 0.16
        ? 1.0
        : t < 0.35
            ? (1.0 - (t - 0.16) / 0.19).clamp(0.0, 1.0)
            : 0.0;
    if (fade <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.shortestSide * 0.75;
    final paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.3),
        radius: 1.1,
        colors: [
          color.withValues(alpha: 0.85 * fade),
          color.withValues(alpha: 0.45 * fade),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));
    canvas.drawCircle(center, maxRadius, paint);
  }

  @override
  bool shouldRepaint(covariant _FlashPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.color != color;
}

class _ConfettiParticle {
  final double nx; // 시작 x (0..1)
  final double startY; // 시작 y (0..0.35)
  final double fall; // 낙하 거리 (0.5..1.1)
  final double sway; // 좌우 흔들림 폭 (0.02..0.08)
  final double freq; // 흔들림 주파수
  final double phase;
  final double rotSpeed; // 회전 속도 (라디안)
  final double width;
  final double height;
  final double radius;
  final double alpha;
  final bool isCircle;
  final Color color;

  _ConfettiParticle.random(math.Random rand, List<Color> palette, double scale)
    : nx = rand.nextDouble(),
      startY = rand.nextDouble() * 0.35,
      fall = 0.5 + rand.nextDouble() * 0.6,
      sway = 0.02 + rand.nextDouble() * 0.06,
      freq = 4 + rand.nextDouble() * 6,
      phase = rand.nextDouble() * math.pi * 2,
      rotSpeed = (rand.nextDouble() - 0.5) * 12,
      width = (4 + rand.nextDouble() * 5) * scale,
      height = (7 + rand.nextDouble() * 6) * scale,
      radius = (2.5 + rand.nextDouble() * 3) * scale,
      alpha = 0.7 + rand.nextDouble() * 0.3,
      isCircle = rand.nextBool(),
      color = palette[rand.nextInt(palette.length)];
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> _particles;
  final Animation<double> _controller;

  _ConfettiPainter({
    required this._controller,
    required List<Color> palette,
    required int count,
    required double scale,
  }) : _particles = _buildParticles(palette, count, scale);

  static List<_ConfettiParticle> _buildParticles(
    List<Color> palette,
    int count,
    double scale,
  ) {
    final rand = math.Random();
    return List.generate(
      count,
      (_) => _ConfettiParticle.random(rand, palette, scale),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = _controller.value;
    // 마지막 25% 구간에서 페이드아웃
    final fade = t < 0.75 ? 1.0 : (1.0 - (t - 0.75) / 0.25).clamp(0.0, 1.0);
    if (fade <= 0) return;

    final paint = Paint();
    for (final p in _particles) {
      final x = (p.nx + math.sin(t * p.freq + p.phase) * p.sway) * size.width;
      final y = (p.startY + t * p.fall) * size.height;
      final alpha = fade * p.alpha;
      paint.color = p.color.withValues(alpha: alpha);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * p.rotSpeed);
      if (p.isCircle) {
        canvas.drawCircle(Offset.zero, p.radius, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.width,
            height: p.height,
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}

/// 12b. 미해금 배지 잠금 뱃지 (우하단 자물쇠 오버레이)
/// 미해금 업적 배지가 잠겼음을 명확히 보여준다.
/// [diameter]는 뱃지 지름, [iconSize]는 자물쇠 아이콘 크기.
/// 달성(해금) 상태를 보여주는 ✓ 칩 — 가이드 조건 카드·수료증 공용.
/// accent 테두리 + 체크 아이콘 + labelMono 소형 텍스트.
class CabinetAchievedChip extends StatelessWidget {
  final String text;
  final CabinetColors colors;
  final double fontSize;

  const CabinetAchievedChip({
    super.key,
    required this.text,
    required this.colors,
    this.fontSize = 9,
  });

  @override
  Widget build(BuildContext context) {
    final theme = CabinetTheme(colors);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: colors.accent, width: 1),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, size: fontSize + 2, color: colors.accent),
          const SizedBox(width: 4),
          Text(
            text,
            style: theme.labelMono.copyWith(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: colors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class CabinetLockBadge extends StatelessWidget {
  final CabinetColors colors;
  final double diameter;
  final double iconSize;

  const CabinetLockBadge({
    super.key,
    required this.colors,
    this.diameter = 18,
    this.iconSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.paper2,
        border: Border.all(color: colors.inkLineStrong, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Icon(
        Icons.lock_outline,
        size: iconSize,
        color: colors.ink3,
      ),
    );
  }
}

/// 12c. 잠긴(미해금) 대형 배지: 진행 링 + 실루엣 아이콘 + 우하단 잠금 뱃지.
/// 업적 상세 화면·마스터 가이드 화면이 공용으로 사용한다 (단일 진실 원천).
/// [size]는 전체 정사각 크기, [iconFraction]/[lockFraction]으로 비례 배치한다.
class CabinetLockedBadge extends StatelessWidget {
  final double progress; // 0~1 진행률
  final CabinetColors colors;
  final double size;
  final IconData icon;
  final double strokeWidth;
  final double iconFraction;
  final double lockFraction;

  const CabinetLockedBadge({
    super.key,
    required this.progress,
    required this.colors,
    required this.size,
    required this.icon,
    this.strokeWidth = 8,
    this.iconFraction = 0.34,
    this.lockFraction = 0.2,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 진행도 링 (단계별 색상)
        CircularProgressIndicator(
          value: progress,
          strokeWidth: strokeWidth,
          strokeCap: StrokeCap.round,
          backgroundColor: colors.inkLine,
          valueColor: AlwaysStoppedAnimation<Color>(
            colors.progressHeat(progress),
          ),
        ),
        Center(
          child: Container(
            width: size * 0.82,
            height: size * 0.82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.paper3,
              border: Border.all(color: colors.inkLineStrong, width: 2.5),
            ),
            child: Icon(
              icon,
              // 회색 실루엣 (아이콘 형태 유지)
              color: colors.inkLineStrong,
              size: size * iconFraction,
            ),
          ),
        ),
        // 우하단 잠금 뱃지
        Positioned(
          right: size * 0.02,
          bottom: size * 0.02,
          child: CabinetLockBadge(
            colors: colors,
            diameter: size * lockFraction,
            iconSize: size * lockFraction * 0.6,
          ),
        ),
      ],
    );
  }
}

/// 12. 해금 배지 스파클 (반짝임 애니메이션)
/// 해금된 배지 주위로 4-포인트 별들이 반짝이며 깜빡인다.
/// [color]는 배지 색, [scale]은 별 크기 배율 (상세 화면용 큰 배지).
class CabinetSparkle extends StatefulWidget {
  final Color color;
  final double scale;

  const CabinetSparkle({
    super.key,
    required this.color,
    this.scale = 1.0,
  });

  @override
  State<CabinetSparkle> createState() => _CabinetSparkleState();
}

class _CabinetSparkleState extends State<CabinetSparkle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        painter: _SparklePainter(
          t: _controller.value,
          color: widget.color,
          scale: widget.scale,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// 스파클 페인터: 결정적(deterministic) 위치·위상으로 별을 그려 반짝인다.
/// t(0~1 반복)에 따라 각 별의 크기·불투명도가 사인파로 맥동한다.
class _SparklePainter extends CustomPainter {
  final double t;
  final Color color;
  final double scale;

  _SparklePainter({required this.t, required this.color, this.scale = 1.0});

  /// 별 8개: [반지름 배율(짧은 변 기준), 각도(라디안), 위상 오프셋].
  /// 배지 아이콘(중앙)을 피해 링/배지 가장자리 부근(0.52~0.64)에 배치한다.
  /// 결정적 위치라 테스트에서 재현 가능하고 프레임마다 일관되게 그려진다.
  static const List<(double, double, double)> _stars = [
    (0.62, -0.6, 0.0),
    (0.58, 0.9, 1.2),
    (0.64, 2.4, 2.1),
    (0.60, 3.9, 3.3),
    (0.56, 5.3, 0.7),
    (0.52, 0.2, 1.9),
    (0.54, 1.8, 2.8),
    (0.58, 3.2, 4.0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.shortestSide / 2;
    final paint = Paint()..style = PaintingStyle.fill;

    for (final (rFrac, angle, phase) in _stars) {
      // 사인파 맥동: 별마다 위상을 달리해 자연스러운 반짝임
      final wave = 0.5 + 0.5 * math.sin(t * 2 * math.pi + phase);
      final radius = (3.2 + 1.6 * wave) * scale;
      final alpha = 0.25 + 0.6 * wave; // 0.25~0.85 (항상 0~1 범위)
      final pos = center +
          Offset(
            math.cos(angle) * baseRadius * rFrac,
            math.sin(angle) * baseRadius * rFrac,
          );

      paint.color = color.withValues(alpha: alpha);
      canvas.drawPath(_starPath(pos, radius), paint);
    }
  }

  /// 4-포인트 별 모양 패스 (세로로 긴 마름모 별).
  Path _starPath(Offset center, double radius) {
    final path = Path();
    // 위 → 오른쪽 → 아래 → 왼쪽 포인트 (꼭짓점 4개 + 안쪽 오목 점 4개)
    final pts = [
      Offset(0, -radius),
      Offset(radius * 0.18, -radius * 0.18),
      Offset(radius, 0),
      Offset(radius * 0.18, radius * 0.18),
      Offset(0, radius),
      Offset(-radius * 0.18, radius * 0.18),
      Offset(-radius, 0),
      Offset(-radius * 0.18, -radius * 0.18),
    ];
    path.moveTo(center.dx + pts[0].dx, center.dy + pts[0].dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(center.dx + pts[i].dx, center.dy + pts[i].dy);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.color != color ||
      oldDelegate.scale != scale;
}
