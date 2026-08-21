/// 단어 정원(Word Garden) 및 식물 페인터
library;
import 'cabinet_surfaces.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/cabinet_colors.dart';
import '../../core/theme/cabinet_theme.dart';

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
