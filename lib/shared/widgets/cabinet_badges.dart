/// 배지 카드·칩·잠금 배지 위젯
library;
import 'cabinet_surfaces.dart';
import 'package:flutter/material.dart';
import '../../core/theme/cabinet_colors.dart';
import '../../core/theme/cabinet_theme.dart';
import '../../core/utils/format_count.dart' as format_util;

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
