import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/cabinet_colors.dart';
import '../core/theme/cabinet_theme.dart';
import '../features/words/presentation/screens/word_list_screen.dart';
import '../features/review/presentation/screens/review_screen.dart';
import '../features/quiz/presentation/screens/quiz_screen.dart';
import '../features/matching/presentation/screens/matching_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/settings/data/services/backup_service.dart';
import '../features/settings/data/services/review_reminder_service.dart';
import '../features/achievements/data/anniversary_service.dart';
import '../features/achievements/presentation/achievement_toast_overlay.dart';
import 'home_dashboard_screen.dart';

final currentTabIndexProvider = StateProvider<int>((ref) => 0);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _triggerAutoBackup();
    _checkReviewReminder();
    _checkAnniversary();
    _refreshHomeWidget();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _triggerAutoBackup();
    }
  }

  /// 홈 화면 위젯 스냅샷 최신화 (모바일 전용, 미지원 플랫폼은 내부 무시).
  Future<void> _refreshHomeWidget() async {
    try {
      await ref.read(homeWidgetServiceProvider).refreshWidgetData();
    } catch (_) {}
  }

  Future<void> _triggerAutoBackup() async {
    try {
      final backupService = ref.read(backupServiceProvider);
      final enabled = await backupService.isAutoBackupEnabled();
      if (enabled) {
        await backupService.autoBackup();
      }
    } catch (_) {}
  }

  Future<void> _checkReviewReminder() async {
    try {
      final reminderService = ref.read(reviewReminderServiceProvider);
      await reminderService.init();
      // 지정 시간 매일 반복 예약 재구성 (설정 변경·재부팅 후에도 유지)
      await reminderService.scheduleDailyReminder();
      // 즉시 알림: 앱을 켰을 때 오늘 미복습 + 복습 대상이 있으면 바로 안내
      final shouldShow = await reminderService.shouldShowReminder();
      if (shouldShow && mounted) {
        await reminderService.showNotification();
      }
    } catch (_) {}
  }

  /// 마스터 정원 기념일 감지: 오늘이 달성 기념일이면 모바일 시스템 알림을
  /// 시도한다 (데스크톱/웹은 미지원이라 무시되고, 인앱 배너가 대신 동작).
  Future<void> _checkAnniversary() async {
    try {
      final service = ref.read(anniversaryServiceProvider);
      final isToday = await service.isAnniversaryToday();
      if (!isToday) return;
      final reminderService = ref.read(reviewReminderServiceProvider);
      await reminderService.showAnniversaryNotification();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(currentTabIndexProvider);
    final themeMode = ref.watch(cabinetThemeModeProvider);
    final colors = CabinetColors.fromMode(themeMode);
    final theme = CabinetTheme(colors);

    final screens = const [
      HomeDashboardScreen(),
      WordListScreen(),
      ReviewScreen(),
      QuizScreen(),
      MatchingScreen(),
      SettingsScreen(),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth > 720;

        return Scaffold(
          backgroundColor: colors.paper,
          appBar: isWideScreen
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(60),
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors.paper2,
                      border: Border(bottom: BorderSide(color: colors.inkLineStrong)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Cabinet Brand Logo
                          Row(
                            children: [
                              Text(
                                'CABINET',
                                style: theme.wordTitle.copyWith(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('· Archival Notebook', style: theme.labelMono.copyWith(fontSize: 9)),
                            ],
                          ),
                          const SizedBox(width: 16),
                          // Desktop Nav Tabs
                          Row(
                            children: [
                              _buildNavTab(0, '01 HOME', Icons.home, currentIndex, colors, theme),
                              _buildNavTab(1, '02 COLLECTION', Icons.book, currentIndex, colors, theme),
                              _buildNavTab(2, '03 REVIEW', Icons.autorenew, currentIndex, colors, theme),
                              _buildNavTab(3, '04 QUIZ', Icons.help_outline, currentIndex, colors, theme),
                              _buildNavTab(4, '05 MATCH', Icons.grid_view, currentIndex, colors, theme),
                              _buildNavTab(5, '06 SETTINGS', Icons.settings, currentIndex, colors, theme),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : null,
          body: Stack(
            children: [
              IndexedStack(
                index: currentIndex,
                children: screens,
              ),
              // 업적 해금 축하 토스트: 어느 탭에서든 새 해금을 알린다.
              // (터치를 가로채지 않도록 IgnorePointer로 감싼다)
              Positioned(
                top: 12,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Center(
                    child: CabinetAchievementToastOverlay(),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: isWideScreen
              ? null
              : Container(
                  decoration: BoxDecoration(
                    color: colors.paper2,
                    border: Border(top: BorderSide(color: colors.inkLineStrong, width: 1.0)),
                  ),
                  child: BottomNavigationBar(
                    currentIndex: currentIndex,
                    backgroundColor: colors.paper2,
                    selectedItemColor: colors.accent,
                    unselectedItemColor: colors.ink3,
                    type: BottomNavigationBarType.fixed,
                    selectedLabelStyle: theme.labelMono.copyWith(fontSize: 10, fontWeight: FontWeight.w700),
                    unselectedLabelStyle: theme.labelMono.copyWith(fontSize: 9),
                    onTap: (index) {
                      ref.read(currentTabIndexProvider.notifier).state = index;
                    },
                    items: const [
                      BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
                      BottomNavigationBarItem(icon: Icon(Icons.book), label: '컬렉션'),
                      BottomNavigationBarItem(icon: Icon(Icons.autorenew), label: '복습'),
                      BottomNavigationBarItem(icon: Icon(Icons.help_outline), label: '퀴즈'),
                      BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: '매칭'),
                      BottomNavigationBarItem(icon: Icon(Icons.settings), label: '설정'),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildNavTab(
    int index,
    String label,
    IconData icon,
    int currentIndex,
    CabinetColors colors,
    CabinetTheme theme,
  ) {
    final isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () {
        ref.read(currentTabIndexProvider.notifier).state = index;
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colors.paper3 : Colors.transparent,
          borderRadius: BorderRadius.circular(2),
          border: isSelected ? Border.all(color: colors.inkLineStrong) : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: isSelected ? colors.accent : colors.ink3),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.labelMono.copyWith(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected ? colors.accent : colors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
