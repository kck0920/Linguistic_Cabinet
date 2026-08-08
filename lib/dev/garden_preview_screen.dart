import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/theme/cabinet_colors.dart';
import '../core/theme/cabinet_theme.dart';
import '../shared/widgets/cabinet_widgets.dart';

/// 개발용 기능 게이트: 디버그 빌드이거나
/// `--dart-define=GARDEN_PREVIEW=true`로 빌드했을 때만 활성화된다.
const bool kGardenPreviewEnabled =
    kDebugMode || bool.fromEnvironment('GARDEN_PREVIEW');

/// 개발용: 단어 정원 레벨 0~20 전체 모습을 한눈에 보여주는 미리보기 화면.
/// 테마별로 전환해 화분/식물 연출을 확인할 수 있다.
class GardenPreviewScreen extends StatefulWidget {
  const GardenPreviewScreen({super.key});

  @override
  State<GardenPreviewScreen> createState() => _GardenPreviewScreenState();
}

class _GardenPreviewScreenState extends State<GardenPreviewScreen> {
  CabinetThemeMode _mode = CabinetThemeMode.sepia;

  @override
  Widget build(BuildContext context) {
    final colors = CabinetColors.fromMode(_mode);
    final theme = CabinetTheme(colors);

    return CabinetPaperScaffold(
      colors: colors,
      appBar: AppBar(
        backgroundColor: colors.paper2,
        foregroundColor: colors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'GARDEN PREVIEW · DEV',
          style: theme.labelMono.copyWith(fontSize: 12, letterSpacing: 2),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 테마 전환 칩
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: CabinetThemeMode.values.map((m) {
                final selected = m == _mode;
                return GestureDetector(
                  onTap: () => setState(() => _mode = m),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: selected ? colors.accent : colors.paper3,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected ? colors.accent : colors.inkLineStrong,
                      ),
                    ),
                    child: Text(
                      _themeLabel(m),
                      style: theme.labelMono.copyWith(
                        fontSize: 10,
                        color: selected ? colors.paper : colors.ink,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Text(
              'LEVEL 0 ~ ${CabinetWordGarden.maxGardenLevel} · 최종 단계 ${CabinetWordGarden.maxGardenWords}단어 (임계값: 5×n²)',
              style: theme.labelMono.copyWith(color: colors.ink3, fontSize: 9),
            ),
            const SizedBox(height: 16),

            // 개화 시연: 레벨업 순간 봉오리→꽃 애니메이션 체험
            _BloomDemo(colors: colors, theme: theme),
            const SizedBox(height: 20),

            // 레벨별 정원 카드 그리드
            LayoutBuilder(
              builder: (context, constraints) {
                final double itemWidth;
                if (constraints.maxWidth >= 1100) {
                  itemWidth = 320;
                } else if (constraints.maxWidth >= 760) {
                  itemWidth = 290;
                } else if (constraints.maxWidth >= 520) {
                  itemWidth = 260;
                } else {
                  itemWidth = constraints.maxWidth; // 모바일 1열 (오버플로 방지)
                }
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: List.generate(
                    CabinetWordGarden.maxGardenLevel + 1,
                    (level) =>
                        _buildLevelCard(colors, theme, level, itemWidth),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelCard(
    CabinetColors colors,
    CabinetTheme theme,
    int level,
    double width,
  ) {
    // 해당 레벨의 중간 지점 단어 수를 주면 그 레벨 식물이 보이고
    // 진행바도 반쯤 차서 실제 사용 중 모습에 가깝게 표시된다.
    final minWords = CabinetWordGarden.thresholdForLevel(level);
    final nextMin = CabinetWordGarden.thresholdForLevel(level + 1);
    final words = level >= CabinetWordGarden.maxGardenLevel
        ? CabinetWordGarden.maxGardenWords
        : (minWords + nextMin) ~/ 2;
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CabinetWordGarden(
            colors: colors,
            totalCount: words,
            masteredCount: 0,
          ),
          const SizedBox(height: 6),
          Text(
            'LVL $level / ${CabinetWordGarden.maxGardenLevel} · $words words',
            style: theme.labelMono.copyWith(fontSize: 9, color: colors.ink3),
          ),
        ],
      ),
    );
  }

  String _themeLabel(CabinetThemeMode m) => switch (m) {
        CabinetThemeMode.sepia => 'SEPIA',
        CabinetThemeMode.forest => 'FOREST',
        CabinetThemeMode.lavender => 'LAVENDER',
        CabinetThemeMode.sunset => 'SUNSET',
        CabinetThemeMode.mono => 'MONO',
      };
}

/// 개화 시연: 버튼을 누르면 단어 수를 단계적으로 올려
/// 레벨업 순간 봉오리→꽃 개화 애니메이션을 재생한다.
class _BloomDemo extends StatefulWidget {
  final CabinetColors colors;
  final CabinetTheme theme;

  const _BloomDemo({required this.colors, required this.theme});

  @override
  State<_BloomDemo> createState() => _BloomDemoState();
}

class _BloomDemoState extends State<_BloomDemo> {
  // 레벨 5 → 9 → 13 → 17 → 20으로 점프하며 개화를 반복 재생
  static const _stageWords = [500, 1125, 1805, 2000];
  int _stage = 0;

  void _nextStage() {
    setState(() => _stage = (_stage + 1) % (_stageWords.length + 1));
  }

  int get _count {
    if (_stage == 0) return 124; // 레벨 4 (봉오리 상태)
    return _stageWords[_stage - 1];
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final theme = widget.theme;
    return CabinetPaperCard(
      colors: colors,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // 시연 정원 (레벨이 단계적으로 올라가며 개화)
          SizedBox(
            width: 170,
            child: CabinetWordGarden(
              colors: colors,
              totalCount: _count,
              masteredCount: 0,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('BLOOM DEMO', style: theme.labelMono),
                const SizedBox(height: 4),
                Text(
                  '버튼을 누르면 레벨이 올라가며 새로 핀 꽃이 봉오리→꽃으로 펼쳐집니다.',
                  style: theme.bodySans.copyWith(color: colors.ink3, fontSize: 12),
                ),
                const SizedBox(height: 12),
                CabinetBrutalButton(
                  text: '개화 재생 (LVL ${_demoLevel()})',
                  icon: Icons.auto_awesome,
                  onPressed: _nextStage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _demoLevel() => CabinetWordGarden.levelForWordCount(_count);
}
