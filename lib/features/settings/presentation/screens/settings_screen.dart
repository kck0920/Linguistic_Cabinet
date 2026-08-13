import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/cabinet_colors.dart';
import '../../../../core/theme/cabinet_theme.dart';
import '../../../../core/utils/format_count.dart';
import '../../../../shared/widgets/cabinet_widgets.dart';
import '../../data/services/backup_service.dart';
import '../../data/services/review_reminder_service.dart';
import '../../../words/presentation/screens/word_list_screen.dart';
import '../../../review/data/models/review_card.dart';
import '../../../review/data/repositories/review_repository.dart';
import '../../../review/presentation/screens/review_screen.dart';
import '../../../quiz/presentation/screens/quiz_screen.dart';
import '../../../matching/presentation/screens/matching_screen.dart';
import '../../../../shared/services/google_auth_service.dart';
import '../../../../shared/services/google_drive_sync_service.dart';
import '../../../../home/home_dashboard_screen.dart';
import '../../../../dev/garden_preview_screen.dart';

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

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _activeSubTab = 0; // 0: Themes, 1: Algo, 2: Data, 3: Stats
  bool _autoBackupEnabled = false;
  bool _reminderEnabled = false;
  String _reminderTime = '09:00';
  bool _isGoogleSyncing = false;
  StreamSubscription<GoogleAuthUser?>? _authSub;

  @override
  void initState() {
    super.initState();
    _loadAutoBackupSetting();
    _loadReminderSetting();
    _trySilentSignInGoogle();
    _authSub = GoogleAuthService().onCurrentUserChanged.listen((account) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _trySilentSignInGoogle() async {
    final account = await GoogleAuthService().signInSilently();
    if (account != null && mounted) {
      setState(() {});
    }
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

  Future<void> _loadReminderSetting() async {
    final reminderService = ref.read(reviewReminderServiceProvider);
    final enabled = await reminderService.isReminderEnabled();
    final time = await reminderService.getReminderTime();
    if (mounted) {
      setState(() {
        _reminderEnabled = enabled;
        _reminderTime = time;
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
        _buildAutoDifficultyToggle(colors, theme),
      ],
    );
  }

  /// 복습 결과 → 단어 난이도 자동 반영 토글
  Widget _buildAutoDifficultyToggle(CabinetColors colors, CabinetTheme theme) {
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
              _buildGoogleDriveSyncSection(colors, theme),
              Text('AUTOMATIC LOCAL BACKUP', style: theme.labelMono),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('앱 시작 시 자동 백업', style: theme.wordTitle.copyWith(fontSize: 18)),
                subtitle: Text('로컬 스토리지에 안전하게 단어장을 보관합니다.', style: theme.bodySans),
                value: _autoBackupEnabled,
                activeThumbColor: colors.accent,
                onChanged: (val) async {
                  final backupService = ref.read(backupServiceProvider);
                  await backupService.setAutoBackupEnabled(val);
                  setState(() => _autoBackupEnabled = val);
                },
              ),
              const Divider(height: 24),

              Text('REVIEW REMINDER', style: theme.labelMono),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('복습 리마인더', style: theme.wordTitle.copyWith(fontSize: 18)),
                subtitle: Text('지정 시간에 매일 복습 알림을 보냅니다.', style: theme.bodySans),
                value: _reminderEnabled,
                activeThumbColor: colors.accent,
                onChanged: (val) => _setReminderEnabled(val),
              ),
              if (_reminderEnabled) ...[
                const SizedBox(height: 4),
                _buildReminderTimeRow(colors, theme),
              ],
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
    ref.invalidate(masteredCountProvider);

    // Quiz & Matching
    ref.invalidate(quizWordsProvider);
    ref.invalidate(matchingWordsProvider);

    // Home & Streak
    ref.invalidate(streakDataProvider);

    // 홈 화면 위젯도 최신 데이터로 갱신 (가져오기·전체 삭제 후)
    ref.read(homeWidgetServiceProvider).refreshWidgetData();
  }

  /// 복습 리마인더 활성화/비활성화: 설정 저장 + 예약 재구성.
  Future<void> _setReminderEnabled(bool val) async {
    final reminderService = ref.read(reviewReminderServiceProvider);
    await reminderService.setReminderEnabled(val);
    setState(() => _reminderEnabled = val);
    if (val) {
      await reminderService.scheduleDailyReminder();
    } else {
      await reminderService.cancelReminder();
    }
  }

  /// 알림 시간 선택: TimePicker로 HH:mm 지정 후 예약 재구성.
  Future<void> _pickReminderTime() async {
    final parts = _reminderTime.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.isNotEmpty ? parts[0] : '09') ?? 9,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    final formatted = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    final reminderService = ref.read(reviewReminderServiceProvider);
    await reminderService.setReminderTime(formatted);
    await reminderService.scheduleDailyReminder();
    if (mounted) {
      setState(() => _reminderTime = formatted);
    }
  }

  /// 알림 시간 표시 행 (탭하면 시간 선택).
  Widget _buildReminderTimeRow(CabinetColors colors, CabinetTheme theme) {
    return InkWell(
      onTap: _pickReminderTime,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.paper3,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: colors.inkLineStrong),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('알림 시간', style: theme.labelMono.copyWith(fontSize: 9)),
                Text(
                  _reminderTime,
                  style: theme.wordTitle.copyWith(fontSize: 18, color: colors.accent),
                ),
              ],
            ),
            Text('변경', style: theme.labelMono.copyWith(color: colors.accent)),
          ],
        ),
      ),
    );
  }

  /// 4. Stats Tab
  Widget _buildStatsTab(CabinetColors colors, CabinetTheme theme) {
    final wordsAsync = ref.watch(wordListProvider);
    final words = wordsAsync.value ?? [];
    final totalWords = words.length;
    // 숙달 수는 공용 프로바이더(getMasteredCount)의 단일 진실 원천을 사용한다.
    final masteredAsync = ref.watch(masteredCountProvider);
    final mastered = masteredAsync.value ?? 0;
    // 숙달 진행률: 전체 수집 단어 중 숙달(난이도 ≤ 2) 비율 (대시보드 타일과 동일 형식)
    final masteredPct = totalWords > 0 ? (mastered / totalWords * 100).round() : 0;

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
                      Text(
                        totalWords > 0
                            ? '${formatCount(mastered)} / ${formatCount(totalWords)}'
                            : '0',
                        style: theme.displaySerif.copyWith(fontSize: 32, color: colors.accent3),
                      ),
                      if (totalWords > 0)
                        Text(
                          '$masteredPct% 숙달',
                          style: theme.labelMono.copyWith(fontSize: 9, color: colors.accent3),
                        ),
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
        if (kGardenPreviewEnabled) ...[
          const SizedBox(height: 24),
          Text('DEV TOOLS', style: theme.labelMono),
          const SizedBox(height: 10),
          CabinetPaperCard(
            colors: colors,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('단어 정원 미리보기', style: theme.wordTitle.copyWith(fontSize: 16)),
                const SizedBox(height: 6),
                Text(
                  '레벨 0~20 화분/식물 모습을 개발용으로 확인합니다.',
                  style: theme.bodySans.copyWith(color: colors.ink3),
                ),
                const SizedBox(height: 12),
                CabinetBrutalButton(
                  text: '정원 미리보기 열기',
                  icon: Icons.grass,
                  fullWidth: true,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const GardenPreviewScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
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

  Widget _buildGoogleDriveSyncSection(CabinetColors colors, CabinetTheme theme) {
    final googleUserAsync = ref.watch(googleUserProvider);
    final user = googleUserAsync.valueOrNull;
    final isSyncing = _isGoogleSyncing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('GOOGLE DRIVE SYNC', style: theme.labelMono),
            if (user != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: colors.accent.withValues(alpha: 0.4), width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 14, color: colors.accent),
                    const SizedBox(width: 4),
                    Text(
                      'GOOGLE 계정과 연동됨',
                      style: theme.labelMono.copyWith(
                        color: colors.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (user == null) ...[
          Text('구글 드라이브(appdata)에 단어장을 안전하게 백업 및 동기화합니다.', style: theme.bodySans.copyWith(fontSize: 13, color: colors.ink3)),
          const SizedBox(height: 12),
          CabinetBrutalButton(
            text: 'Google 계정 연결하기',
            icon: Icons.cloud_queue,
            fullWidth: true,
            onPressed: () async {
              try {
                final account = await ref.read(googleUserProvider.notifier).signIn();
                if (account != null && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${account.email} 계정과 연결되었습니다.')),
                  );
                  _triggerGoogleSync();
                }
              } catch (e) {
                if (mounted) {
                  final errStr = e.toString();
                  final errMsg = (errStr.contains('appClientId != null') || errStr.contains('ClientId not set'))
                      ? 'Google OAuth Client ID 설정이 필요합니다. (Google Cloud Console 발급 필요)'
                      : 'Google 로그인 실패: $e';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(errMsg)),
                  );
                }
              }
            },
          ),
        ] else ...[
          Text('구글 드라이브(appdata)와 데이터가 안전하게 자동 연동 중입니다.', style: theme.bodySans.copyWith(fontSize: 13, color: colors.ink3)),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: colors.accent,
              backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
              child: user.photoUrl == null
                  ? Text(user.email.isNotEmpty ? user.email[0].toUpperCase() : 'G', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                  : null,
            ),
            title: Text(user.displayName ?? user.email, style: theme.wordTitle.copyWith(fontSize: 16)),
            subtitle: Text(user.email, style: theme.bodySans.copyWith(fontSize: 12, color: colors.ink3)),
          ),
          const SizedBox(height: 8),
            Row(
            children: [
              Expanded(
                child: CabinetBrutalButton(
                  text: isSyncing ? '동기화 중...' : '지금 동기화',
                  icon: isSyncing ? Icons.sync : Icons.cloud_sync,
                  onPressed: () {
                    if (!isSyncing) _triggerGoogleSync();
                  },
                ),
              ),
              const SizedBox(width: 8),
              CabinetBrutalButton(
                text: '연결 해제',
                icon: Icons.logout,
                bg: colors.paper2,
                textColor: colors.ink,
                onPressed: () async {
                  await ref.read(googleUserProvider.notifier).signOut();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Google 계정 연결이 해제되었습니다.')),
                    );
                  }
                },
              ),
            ],
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                await GoogleAuthService().forceExpireAccessToken();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('[디버그] 토큰이 강제로 만료 처리되었습니다. "지금 동기화"를 눌러 갱신을 테스트하세요.')),
                  );
                }
              },
              icon: const Icon(Icons.timer_off, size: 14),
              label: const Text('토큰 만료 테스트 (디버그)', style: TextStyle(fontSize: 12)),
            ),
          ],
        ],
        const Divider(height: 24),
      ],
    );
  }

  Future<void> _triggerGoogleSync() async {
    setState(() => _isGoogleSyncing = true);
    // 수동 동기화는 사용자 제스처이므로, 토큰 만료 시 팝업/리다이렉트 재인증을
    // 허용해 모바일 웹에서 1시간이 지나도 연결이 유지되도록 한다.
    final success = await GoogleDriveSyncService().sync(interactive: true);
    if (mounted) {
      setState(() => _isGoogleSyncing = false);
      if (success) {
        _refreshAllProviders();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google Drive 동기화가 성공적으로 완료되었습니다!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google Drive 동기화 실패. 네트워크나 계정 상태를 확인해 주세요.')),
        );
      }
    }
  }
}
