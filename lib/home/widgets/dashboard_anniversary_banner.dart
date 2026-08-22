import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/cabinet_colors.dart';
import '../../core/theme/cabinet_theme.dart';
import '../../features/achievements/data/anniversary_service.dart';

/// 기념일 축하 배너: 오늘이 마스터 정원 달성 기념일이면 표시.
/// 배너를 탭하면 만개 축하 연출(컨페티+플래시)이 재생된다.
class DashboardAnniversaryBanner extends ConsumerWidget {
  const DashboardAnniversaryBanner({super.key, required this.onCelebrate});

  /// 축하 연출 트리거 (화면 전체 컨페티 — 대시보드 셸에서 처리)
  final VoidCallback onCelebrate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(cabinetThemeModeProvider);
    final colors = CabinetColors.fromMode(themeMode);
    final theme = CabinetTheme(colors);

    return GestureDetector(
      onTap: () async {
        try {
          final service = ref.read(anniversaryServiceProvider);
          await service.markAnniversaryCelebrated();
          ref.invalidate(anniversaryTodayProvider);
        } catch (_) {
          // 기록 실패는 치명적이지 않음 (다음 실행에 재시도)
        }
        // 만개 스페셜(황금 고리+꽃가루+플래시) 연출을 재생한다.
        onCelebrate();
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          decoration: BoxDecoration(
            color: colors.tapeYellow.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: colors.accent, width: 1.5),
          ),
          child: Row(
            children: [
              const Text('🎉', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MASTER GARDENER ANNIVERSARY',
                      style: theme.labelMono.copyWith(
                        color: colors.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '1년 전 오늘, 2,000단어를 모아 정원을 완성했어요.\n탭하면 축하 연출이 재생됩니다.',
                      style: theme.bodySans.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '닫기',
                icon: Icon(Icons.close, size: 18, color: colors.ink3),
                onPressed: () async {
                  try {
                    final service = ref.read(anniversaryServiceProvider);
                    await service.markAnniversaryCelebrated();
                    ref.invalidate(anniversaryTodayProvider);
                  } catch (_) {}
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
