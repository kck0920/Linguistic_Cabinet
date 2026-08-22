import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/cabinet_colors.dart';
import '../../../../core/theme/cabinet_theme.dart';
import '../../../../shared/widgets/cabinet_widgets.dart';
import '../../../review/data/models/review_card.dart';
import '../../../review/data/repositories/review_repository.dart';
import '../../../review/presentation/screens/review_screen.dart';

final reviewMethodProvider = FutureProvider<ReviewMethod>((ref) async {
  final repo = ref.watch(reviewRepositoryProvider);
  final value = await repo.getSetting('review_method');
  switch (value) {
    case 'fixed':
      return ReviewMethod.fixed;
    case 'sm2':
      return ReviewMethod.sm2;
    default:
      return ReviewMethod.linear;
  }
});

final fixedIntervalDaysProvider = FutureProvider<int?>((ref) async {
  final repo = ref.watch(reviewRepositoryProvider);
  final value = await repo.getSetting('fixed_interval_days');
  return value != null ? int.tryParse(value) : null;
});

/// 복습 결과 → 단어 난이도 자동 반영 여부 (기본: 켬).
/// 설정 키가 'false'면 꺼짐, 그 외(설정 없음 포함)는 켜짐.
final autoDifficultyEnabledProvider = FutureProvider<bool>((ref) async {
  final repo = ref.watch(reviewRepositoryProvider);
  final value = await repo.getSetting(ReviewRepository.autoDifficultySettingKey);
  return value == null || value != 'false';
});

/// 설정 화면 2번 탭 — 복습 알고리즘 선택
class SettingsAlgoTab extends ConsumerWidget {
  const SettingsAlgoTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(cabinetThemeModeProvider);
    final colors = CabinetColors.fromMode(themeMode);
    final theme = CabinetTheme(colors);

    final methodAsync = ref.watch(reviewMethodProvider);
    final fixedDaysAsync = ref.watch(fixedIntervalDaysProvider);

    final currentMethod = methodAsync.value ?? ReviewMethod.linear;
    final currentFixedDays = fixedDaysAsync.value ?? 7;

    final algorithms = [
      {
        'method': ReviewMethod.sm2,
        'valueStr': 'sm2',
        'title': 'SuperMemo SM-2 (Intelligent)',
        'sub': '지능형 적응 복습 알고리즘',
        'desc': '사용자의 정답률 및 쉽게 느낀 난이도(Easiness Factor)에 따라 복습 간격을 최적으로 자동 계산합니다.',
        'handNote': '★ 추천: 개인 맞춤형 기억 파괴 곡선 자동 방지',
        'isRec': true,
      },
      {
        'method': ReviewMethod.linear,
        'valueStr': 'linear',
        'title': 'Leitner 5-Box System',
        'sub': '라이트너 5단계 상자 알고리즘',
        'desc': '맞추면 다음 단계 상자로 이동하고, 틀리면 Box 1로 돌아가 1일→3일→7일→14일→30일 단위로 복습합니다.',
        'handNote': '체계적이고 전통적인 카드 복습 방식',
        'isRec': false,
      },
      {
        'method': ReviewMethod.fixed,
        'valueStr': 'fixed',
        'title': 'Fixed Interval System',
        'sub': '고정 일수 주기적 복습',
        'desc': '설정한 일수(예: 7일마다)마다 일정한 주기로 반복 복습합니다.',
        'handNote': '규칙적인 정기 시험 및 과제 대비용',
        'isRec': false,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SELECT SPACED REPETITION ALGORITHM', style: theme.labelMono),
        const SizedBox(height: 14),

        ...algorithms.map((algo) {
          final method = algo['method'] as ReviewMethod;
          final valueStr = algo['valueStr'] as String;
          final isSelected = currentMethod == method;
          final isRec = algo['isRec'] as bool;

          return GestureDetector(
            onTap: () async {
              final repo = ref.read(reviewRepositoryProvider);
              await repo.setSetting('review_method', valueStr);
              ref.invalidate(reviewMethodProvider);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isSelected ? colors.paper3 : colors.paper2,
                borderRadius: BorderRadius.circular(2),
                border: Border.all(
                  color: isSelected ? colors.accent : colors.inkLineStrong,
                  width: isSelected ? 2.0 : 1.0,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: colors.accent.withValues(alpha: 0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? colors.accent : Colors.transparent,
                              border: Border.all(
                                color: isSelected ? colors.accent : colors.inkLineStrong,
                                width: 2,
                              ),
                            ),
                            child: isSelected
                                ? Icon(Icons.check, size: 14, color: colors.paper)
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Text(algo['title'] as String, style: theme.wordTitle.copyWith(fontSize: 18)),
                        ],
                      ),
                      if (isRec)
                        CabinetStamp(text: 'RECOMMENDED', color: colors.accent3, fontSize: 9)
                      else if (isSelected)
                        CabinetStamp(text: 'ACTIVE', color: colors.accent, fontSize: 9),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(algo['desc'] as String, style: theme.bodySans.copyWith(color: colors.ink2)),
                  const SizedBox(height: 8),
                  Text(algo['handNote'] as String, style: theme.handNote.copyWith(fontSize: 16)),

                  // Fixed interval options if selected
                  if (method == ReviewMethod.fixed && isSelected) ...[
                    const Divider(height: 20),
                    Text('FIXED INTERVAL DAYS (고정 주기 선택):', style: theme.labelMono.copyWith(fontSize: 9)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: [1, 2, 3, 7, 14, 30].map((days) {
                        final isDaysSelected = currentFixedDays == days;
                        return GestureDetector(
                          onTap: () async {
                            final repo = ref.read(reviewRepositoryProvider);
                            await repo.setSetting('fixed_interval_days', days.toString());
                            ref.invalidate(fixedIntervalDaysProvider);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDaysSelected ? colors.accent : colors.paper2,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: isDaysSelected ? colors.accent : colors.inkLineStrong,
                              ),
                            ),
                            child: Text(
                              '$days일마다',
                              style: theme.labelMono.copyWith(
                                fontSize: 10,
                                color: isDaysSelected ? colors.paper : colors.ink,
                                fontWeight: isDaysSelected ? FontWeight.w700 : FontWeight.w400,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        _buildAutoDifficultyToggle(ref, colors, theme),
      ],
    );
  }

  /// 복습 결과 → 단어 난이도 자동 반영 토글
  Widget _buildAutoDifficultyToggle(WidgetRef ref, CabinetColors colors, CabinetTheme theme) {
    final autoDifficultyAsync = ref.watch(autoDifficultyEnabledProvider);
    final enabled = autoDifficultyAsync.value ?? true;

    return CabinetPaperCard(
      colors: colors,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('복습 결과 난이도 자동 반영', style: theme.wordTitle.copyWith(fontSize: 16)),
        subtitle: Text(
          '정답 시 난이도 1 하락, 오답 시 1 상승 (1~5 범위). MASTERED(난이도 ≤ 2) 집계에 자동 반영됩니다.',
          style: theme.bodySans.copyWith(color: colors.ink3),
        ),
        value: enabled,
        activeThumbColor: colors.accent,
        onChanged: (val) async {
          final repo = ref.read(reviewRepositoryProvider);
          await repo.setSetting(ReviewRepository.autoDifficultySettingKey, val ? 'true' : 'false');
          ref.invalidate(autoDifficultyEnabledProvider);
        },
      ),
    );
  }
}
