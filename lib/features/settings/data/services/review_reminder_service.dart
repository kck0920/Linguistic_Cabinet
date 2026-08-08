import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../review/data/repositories/review_repository.dart';
import '../../../review/presentation/screens/review_screen.dart';

class ReviewReminderService {
  final ReviewRepository _reviewRepository;
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  ReviewReminderService(this._reviewRepository);

  /// 알림 서비스 초기화
  Future<void> init() async {
    const LinuxInitializationSettings initializationSettingsLinux =
        LinuxInitializationSettings(
      defaultActionName: 'Open VocaTree',
    );

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      linux: initializationSettingsLinux,
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
    );

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
    );
  }

  /// 알림이 활성화되어 있는지 확인
  Future<bool> isReminderEnabled() async {
    final value = await _reviewRepository.getSetting('reminder_enabled');
    return value == 'true';
  }

  /// 알림 활성화/비활성화
  Future<void> setReminderEnabled(bool enabled) async {
    await _reviewRepository.setSetting('reminder_enabled', enabled ? 'true' : 'false');
  }

  /// 알림 시간 가져오기 (HH:mm 형식)
  Future<String> getReminderTime() async {
    final value = await _reviewRepository.getSetting('reminder_time');
    return value ?? '09:00'; // 기본값 오전 9시
  }

  /// 알림 시간 설정
  Future<void> setReminderTime(String time) async {
    await _reviewRepository.setSetting('reminder_time', time);
  }

  /// 리뷰 알림이 필요한지 확인 (오늘 아직 복습하지 않았고, 복습 대상이 있는 경우)
  Future<bool> shouldShowReminder() async {
    final enabled = await isReminderEnabled();
    if (!enabled) return false;

    final hasReviewed = await _reviewRepository.hasReviewedToday();
    if (hasReviewed) return false;

    final dueCards = await _reviewRepository.getDueReviewCards();
    return dueCards.isNotEmpty;
  }

  /// 시스템 알림 표시
  Future<void> showNotification() async {
    const LinuxNotificationDetails linuxNotificationDetails = LinuxNotificationDetails();
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'vocatree_reminder',
      '복습 알림',
      channelDescription: 'VocaTree 단어 복습 알림 채널',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      linux: linuxNotificationDetails,
      android: androidNotificationDetails,
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );

    await _notificationsPlugin.show(
      id: 0,
      title: '복습할 시간입니다!',
      body: '오늘 아직 학습하지 않은 단어가 있습니다. 복습을 완료해 보세요.',
      notificationDetails: notificationDetails,
    );
  }

  /// 마스터 정원 기념일 축하 알림 (모바일 전용, 실패 시 무시).
  /// 예약(zonedSchedule)은 데스크톱/웹에서 미지원이므로 앱 실행 중 감지 시
  /// 즉시 표시하는 안전한 폴백 방식으로 동작한다.
  Future<void> showAnniversaryNotification() async {
    try {
      await init();
      const AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
        'vocatree_anniversary',
        '기념일 축하',
        channelDescription: 'VocaTree 마스터 정원 기념일 알림 채널',
        importance: Importance.max,
        priority: Priority.high,
      );
      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
        iOS: DarwinNotificationDetails(),
      );
      await _notificationsPlugin.show(
        id: 1,
        title: '🎉 마스터 정원 기념일!',
        body: '1년 전 오늘, 2,000단어를 모아 정원을 완성했어요. 축하합니다!',
        notificationDetails: notificationDetails,
      );
    } catch (_) {
      // 데스크톱/웹 등 미지원 플랫폼은 무시 (인앱 배너가 대신 동작)
    }
  }
}

final reviewReminderServiceProvider = Provider<ReviewReminderService>((ref) {
  final reviewRepository = ref.watch(reviewRepositoryProvider);
  return ReviewReminderService(reviewRepository);
});
