/// 꽃가루(Confetti)·반짝임(Sparkle) 이펙트
library;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/cabinet_colors.dart';

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
