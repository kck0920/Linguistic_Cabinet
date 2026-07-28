import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/cabinet_colors.dart';
import '../../../../core/theme/cabinet_theme.dart';
import '../../../../shared/widgets/cabinet_widgets.dart';
import '../../data/services/backup_service.dart';
import '../../../words/presentation/screens/word_list_screen.dart';
import '../../../review/data/models/review_card.dart';
import '../../../review/presentation/screens/review_screen.dart';
import '../../../quiz/presentation/screens/quiz_screen.dart';
import '../../../matching/presentation/screens/matching_screen.dart';
import '../../../../home/home_dashboard_screen.dart';

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

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _activeSubTab = 0; // 0: Themes, 1: Algo, 2: Data, 3: Stats
  bool _autoBackupEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadAutoBackupSetting();
  }

  Future<void> _loadAutoBackupSetting() async {
    final backupService = ref.read(backupServiceProvider);
    final enabled = await backupService.isAutoBackupEnabled();
    if (mounted) {
      setState(() {
        _autoBackupEnabled = enabled;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(cabinetThemeModeProvider);
    final colors = CabinetColors.fromMode(themeMode);
    final theme = CabinetTheme(colors);

    return CabinetPaperScaffold(
      colors: colors,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CabinetSectionHead(
              eyebrow: 'Section 06 · Settings',
              title: 'Cabinet Preferences',
              subtitle: 'Theme, Spaced Repetition & Data',
              colors: colors,
            ),
            const SizedBox(height: 20),

            // Top Sub Tab Navigation Bar
            CabinetPaperCard(
              colors: colors,
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _buildSubTabButton('THEMES', 0, colors, theme),
                  const SizedBox(width: 4),
                  _buildSubTabButton('ALGORITHM', 1, colors, theme),
                  const SizedBox(width: 4),
                  _buildSubTabButton('DATA & BACKUP', 2, colors, theme),
                  const SizedBox(width: 4),
                  _buildSubTabButton('STATISTICS', 3, colors, theme),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Sub Tab Content
            Expanded(
              child: SingleChildScrollView(
                child: _buildSubTabContent(colors, theme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubTabButton(String label, int index, CabinetColors colors, CabinetTheme theme) {
    final isSelected = _activeSubTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeSubTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected ? colors.paper3 : Colors.transparent,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: isSelected ? colors.inkLineStrong : Colors.transparent,
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.labelMono.copyWith(
                fontSize: 9.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? colors.accent : colors.ink2,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubTabContent(CabinetColors colors, CabinetTheme theme) {
    switch (_activeSubTab) {
      case 0:
        return _buildThemesTab(colors, theme);
      case 1:
        return _buildAlgoTab(colors, theme);
      case 2:
        return _buildDataTab(colors, theme);
      case 3:
        return _buildStatsTab(colors, theme);
      default:
        return _buildThemesTab(colors, theme);
    }
  }

  /// 1. Themes Tab
  Widget _buildThemesTab(CabinetColors colors, CabinetTheme theme) {
    final currentMode = ref.watch(cabinetThemeModeProvider);

    final themesList = [
      {'mode': CabinetThemeMode.sepia, 'name': 'Sepia Paper', 'sub': 'Classic Archival Paper (Default)'},
      {'mode': CabinetThemeMode.forest, 'name': 'Forest Moss', 'sub': 'Deep Sage & Muted Green'},
      {'mode': CabinetThemeMode.lavender, 'name': 'Lavender Ink', 'sub': 'Soft Violet & Regal Purple'},
      {'mode': CabinetThemeMode.sunset, 'name': 'Sunset Clay', 'sub': 'Warm Terracotta & Mustard'},
      {'mode': CabinetThemeMode.mono, 'name': 'Monochrome', 'sub': 'Minimal Black & Paper White'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SELECT COLOR PALETTE', style: theme.labelMono),
        const SizedBox(height: 14),
        ...themesList.map((t) {
          final mode = t['mode'] as CabinetThemeMode;
          final isSelected = currentMode == mode;
          final paletteColors = CabinetColors.fromMode(mode);

          return GestureDetector(
            onTap: () {
              ref.read(cabinetThemeModeProvider.notifier).setThemeMode(mode);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: paletteColors.paper2,
                borderRadius: BorderRadius.circular(2),
                border: Border.all(
                  color: isSelected ? colors.ink : colors.inkLineStrong,
                  width: isSelected ? 2.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: paletteColors.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: paletteColors.ink),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t['name'] as String, style: theme.wordTitle.copyWith(fontSize: 18)),
                        Text(t['sub'] as String, style: theme.labelMono.copyWith(color: colors.ink3, fontSize: 10)),
                      ],
                    ),
                  ),
                  if (isSelected)
                    CabinetStamp(text: 'ACTIVE', color: colors.accent, fontSize: 10),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  /// 2. Algo Tab
  Widget _buildAlgoTab(CabinetColors colors, CabinetTheme theme) {
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
                          color: colors.accent.withOpacity(0.15),
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
      ],
    );
  }

  /// 3. Data Tab
  Widget _buildDataTab(CabinetColors colors, CabinetTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('DATA BACKUP & PORTABILITY', style: theme.labelMono),
        const SizedBox(height: 14),
        CabinetPaperCard(
          colors: colors,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AUTOMATIC LOCAL BACKUP', style: theme.labelMono),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('앱 시작 시 자동 백업', style: theme.wordTitle.copyWith(fontSize: 18)),
                subtitle: Text('로컬 스토리지에 안전하게 단어장을 보관합니다.', style: theme.bodySans),
                value: _autoBackupEnabled,
                activeColor: colors.accent,
                onChanged: (val) async {
                  final backupService = ref.read(backupServiceProvider);
                  await backupService.setAutoBackupEnabled(val);
                  setState(() => _autoBackupEnabled = val);
                },
              ),
              const Divider(height: 24),

              Text('EXPORT & IMPORT', style: theme.labelMono),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: CabinetBrutalButton(
                      text: '내보내기 (Export)',
                      icon: Icons.download,
                      onPressed: () async {
                        final backupService = ref.read(backupServiceProvider);
                        final count = await backupService.exportBackup();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$count개 단어 내보내기 완료!')),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CabinetBrutalButton(
                      text: '가져오기 (Import)',
                      icon: Icons.upload,
                      bg: colors.paper2,
                      textColor: colors.ink,
                      onPressed: () async {
                        final backupService = ref.read(backupServiceProvider);
                        final res = await backupService.importBackup();
                        if (res != null && mounted) {
                          _refreshAllProviders();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('단어장 복원 완료 (${res.importedCount}개 추가, ${res.updatedCount}개 업데이트)')),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),

              CabinetBrutalButton(
                text: '전체 데이터 초기화',
                icon: Icons.delete_forever,
                bg: Colors.red,
                textColor: Colors.white,
                fullWidth: true,
                onPressed: () => _showClearDialog(colors, theme),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _refreshAllProviders() {
    // Collection & Words
    ref.invalidate(wordListProvider);
    ref.invalidate(filteredWordsProvider);
    ref.read(searchQueryProvider.notifier).state = '';
    ref.read(selectedTagFilterProvider.notifier).state = 'all';
    ref.read(sortOrderProvider.notifier).state = 'recent';

    // Review
    ref.invalidate(dueReviewCardsProvider);
    ref.invalidate(reviewStatsProvider);
    ref.invalidate(hasReviewedTodayProvider);

    // Quiz & Matching
    ref.invalidate(quizWordsProvider);
    ref.invalidate(matchingWordsProvider);

    // Home & Streak
    ref.invalidate(streakDataProvider);
  }

  /// 4. Stats Tab
  Widget _buildStatsTab(CabinetColors colors, CabinetTheme theme) {
    final wordsAsync = ref.watch(wordListProvider);
    final words = wordsAsync.value ?? [];
    final totalWords = words.length;
    final mastered = words.where((w) => w.difficulty <= 2).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('LEARNING STATISTICS', style: theme.labelMono),
        const SizedBox(height: 14),
        CabinetPaperCard(
          colors: colors,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text('TOTAL WORDS', style: theme.labelMono),
                      Text('$totalWords', style: theme.displaySerif.copyWith(fontSize: 32)),
                    ],
                  ),
                  Column(
                    children: [
                      Text('MASTERED', style: theme.labelMono),
                      Text('$mastered', style: theme.displaySerif.copyWith(fontSize: 32, color: colors.accent3)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Monthly Progress', style: theme.wordTitle.copyWith(fontSize: 18)),
              const SizedBox(height: 10),
              SizedBox(
                height: 100,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(20, (i) {
                    final h = (i * 7 + 15) % 80 + 10.0;
                    return Container(
                      width: 8,
                      height: h,
                      decoration: BoxDecoration(
                        color: i > 15 ? colors.accent : colors.inkLineStrong,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showClearDialog(CabinetColors colors, CabinetTheme theme) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colors.paper2,
          title: Text('전체 삭제 확인', style: theme.wordTitle.copyWith(color: Colors.red)),
          content: Text('등록된 모든 단어가 완전히 삭제됩니다.', style: theme.bodySans),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('취소', style: theme.bodySans)),
            CabinetBrutalButton(
              text: '삭제',
              bg: Colors.red,
              textColor: Colors.white,
              onPressed: () async {
                final repo = ref.read(wordRepositoryProvider);
                await repo.deleteAllWords();
                _refreshAllProviders();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('모든 데이터가 삭제되었습니다.')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}
