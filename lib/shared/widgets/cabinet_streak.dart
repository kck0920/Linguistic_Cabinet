/// 연속 학습 잔디밭(Streak) 그리드
library;
import 'cabinet_surfaces.dart';
import 'package:flutter/material.dart';
import '../../core/theme/cabinet_colors.dart';
import '../../core/theme/cabinet_theme.dart';

class CabinetStreakGrid extends StatefulWidget {
  final List<int> streakLevels; // level 0..4 for 182 days
  final CabinetColors colors;

  const CabinetStreakGrid({
    super.key,
    required this.streakLevels,
    required this.colors,
  });

  @override
  State<CabinetStreakGrid> createState() => _CabinetStreakGridState();
}

class _CabinetStreakGridState extends State<CabinetStreakGrid> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToRight();
    });
  }

  @override
  void didUpdateWidget(covariant CabinetStreakGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streakLevels != widget.streakLevels) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToRight();
      });
    }
  }

  void _scrollToRight() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = CabinetTheme(widget.colors);
    final count = widget.streakLevels.where((l) => l > 0).length;

    return CabinetPaperCard(
      colors: widget.colors,
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
                style: theme.labelMono.copyWith(color: widget.colors.accent),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 90,
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: SizedBox(
                width: 26 * 13.5,
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
                    final lvl = index < widget.streakLevels.length
                        ? widget.streakLevels[index]
                        : 0;
                    Color cellColor;
                    if (lvl == 0) {
                      cellColor = widget.colors.inkLine.withValues(alpha: 0.12);
                    } else if (lvl == 1) {
                      cellColor = widget.colors.accent3.withValues(alpha: 0.35);
                    } else if (lvl == 2) {
                      cellColor = widget.colors.accent3.withValues(alpha: 0.55);
                    } else if (lvl == 3) {
                      cellColor = widget.colors.accent3.withValues(alpha: 0.8);
                    } else {
                      cellColor = widget.colors.accent3;
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
                    ? widget.colors.inkLine.withValues(alpha: 0.12)
                    : widget.colors.accent3.withValues(alpha: 0.25 * i);
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
