/// 단어 정원(Word Garden) 및 식물 페인터
library;
import 'cabinet_surfaces.dart';
import 'cabinet_plant_painter.dart';
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

  /// 꽃/봉오리 배치 레이아웃 (테스트용 공개 헬퍼). 단일 소스는 [PlantPainter].
  /// 각 항목: [세로 위치(줄기 상대 높이 0~1), 좌우 오프셋, 색 인덱스].
  /// 줄기 상단(작은 값)부터 중·하단까지 계단식으로 배치된다.
  static List<(double, double, int)> get flowerLayout =>
      PlantPainter.flowerLayout;

  /// 각 꽃 위치가 '꽃'으로 피는 progress 임계값 (위→아래 순차 개화).
  static List<double> get bloomAtProgress => PlantPainter.bloomAtProgress;

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
                  painter: PlantPainter(
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

