import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/cabinet_colors.dart';
import '../../../../core/theme/cabinet_theme.dart';
import '../../../../shared/widgets/cabinet_widgets.dart';
import '../../data/services/backup_service.dart';
import '../../data/services/review_reminder_service.dart';
import '../../../words/presentation/screens/word_list_screen.dart';
import '../../../review/presentation/screens/review_screen.dart';
import '../../../quiz/presentation/screens/quiz_screen.dart';
import '../../../matching/presentation/screens/matching_screen.dart';
import '../../../../shared/services/google_auth_service.dart';
import '../../../../shared/services/google_drive_sync_service.dart';
import '../../../../home/home_dashboard_screen.dart';

/// 설정 화면 3번 탭 — 데이터 백업·동기화·리마인더
class SettingsDataTab extends ConsumerStatefulWidget {
  const SettingsDataTab({super.key});

  @override
  ConsumerState<SettingsDataTab> createState() => _SettingsDataTabState();
}

class _SettingsDataTabState extends ConsumerState<SettingsDataTab> {
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
                      onPressed: _exportBackup,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CabinetBrutalButton(
                      text: '가져오기 (Import)',
                      icon: Icons.upload,
                      bg: colors.paper2,
                      textColor: colors.ink,
                      onPressed: _importBackup,
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

  Future<void> _exportBackup() async {
    final backupService = ref.read(backupServiceProvider);
    final count = await backupService.exportBackup();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$count개 단어 내보내기 완료!')),
    );
  }

  Future<void> _importBackup() async {
    final backupService = ref.read(backupServiceProvider);
    final res = await backupService.importBackup();
    if (res == null || !mounted) return;
    _refreshAllProviders();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('단어장 복원 완료 (${res.importedCount}개 추가, ${res.updatedCount}개 업데이트)')),
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
                  String errMsg = 'Google 로그인 실패: $e';
                  if (errStr.contains('popup_failed_to_open') || errStr.contains('popup_closed')) {
                    errMsg = '아이폰 Safari 팝업 차단으로 창이 열리지 않았습니다. iOS 설정 > Safari > [팝업 차단]을 해제 후 다시 눌러주세요.';
                  } else if (errStr.contains('appClientId != null') || errStr.contains('ClientId not set')) {
                    errMsg = 'Google OAuth Client ID 설정이 필요합니다. (Google Cloud Console 발급 필요)';
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(errMsg),
                      duration: const Duration(seconds: 5),
                    ),
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
    // 수동 동기화 버튼 클릭 시: 사일런트 갱신 우선 시도 후, 필요시 사용자 인터랙티브 갱신까지 허용
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
