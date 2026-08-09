import 'package:flutter_test/flutter_test.dart';

import 'package:linguistic_cabinet/features/review/data/models/review_card.dart';
import 'package:linguistic_cabinet/features/review/data/repositories/review_repository.dart';
import 'package:linguistic_cabinet/features/settings/data/services/review_reminder_service.dart';

/// settings 맵 기반 가짜 리포 (master_badge_test와 동일 패턴).
/// 스케줄 검증은 플러그인 미존재(테스트 환경)에서도 크래시하지 않는지 확인한다.
class FakeReminderRepo extends ReviewRepository {
  final Map<String, String> settings = {};
  bool reviewedToday = false;
  List<ReviewCard> dueCards = [];

  @override
  Future<String?> getSetting(String key) async => settings[key];

  @override
  Future<void> setSetting(String key, String value) async {
    settings[key] = value;
  }

  @override
  Future<bool> hasReviewedToday() async => reviewedToday;

  @override
  Future<List<ReviewCard>> getDueReviewCards() async => dueCards;
}

void main() {
  group('ReviewReminderService 설정', () {
    test('알림 시간 기본값은 09:00이다', () async {
      final service = ReviewReminderService(FakeReminderRepo());
      expect(await service.getReminderTime(), '09:00');
    });

    test('알림 시간 저장/조회 라운드트립', () async {
      final repo = FakeReminderRepo();
      final service = ReviewReminderService(repo);

      await service.setReminderTime('07:30');
      expect(await service.getReminderTime(), '07:30');
      expect(repo.settings['reminder_time'], '07:30');
    });

    test('리마인더 기본은 꺼져 있고, 켜기/끄기가 저장된다', () async {
      final repo = FakeReminderRepo();
      final service = ReviewReminderService(repo);

      expect(await service.isReminderEnabled(), isFalse);

      await service.setReminderEnabled(true);
      expect(await service.isReminderEnabled(), isTrue);
      expect(repo.settings['reminder_enabled'], 'true');

      await service.setReminderEnabled(false);
      expect(await service.isReminderEnabled(), isFalse);
    });
  });

  group('ReviewReminderService.shouldShowReminder', () {
    test('활성 + 오늘 미복습 + 복습 대상 있으면 true', () async {
      final repo = FakeReminderRepo()
        ..settings['reminder_enabled'] = 'true'
        ..reviewedToday = false
        ..dueCards = [
          ReviewCard(
            wordId: 'w1',
            reviewMethod: ReviewMethod.linear,
            nextReviewDate: DateTime.now().subtract(const Duration(days: 1)),
          ),
        ];
      final service = ReviewReminderService(repo);

      expect(await service.shouldShowReminder(), isTrue);
    });

    test('비활성이면 false', () async {
      final repo = FakeReminderRepo()
        ..reviewedToday = false
        ..dueCards = [
          ReviewCard(
            wordId: 'w1',
            reviewMethod: ReviewMethod.linear,
            nextReviewDate: DateTime.now().subtract(const Duration(days: 1)),
          ),
        ];
      final service = ReviewReminderService(repo);

      expect(await service.shouldShowReminder(), isFalse);
    });

    test('오늘 이미 복습했으면 false', () async {
      final repo = FakeReminderRepo()
        ..settings['reminder_enabled'] = 'true'
        ..reviewedToday = true
        ..dueCards = [
          ReviewCard(
            wordId: 'w1',
            reviewMethod: ReviewMethod.linear,
            nextReviewDate: DateTime.now().subtract(const Duration(days: 1)),
          ),
        ];
      final service = ReviewReminderService(repo);

      expect(await service.shouldShowReminder(), isFalse);
    });
  });

  group('ReviewReminderService 스케줄링 안전성', () {
    // 테스트 환경엔 플러그인/타임존 초기화가 없지만, 미지원 플랫폼과 동일하게
    // 내부 try/catch로 무시되어야 한다 (예외가 밖으로 새면 테스트가 실패한다).
    test('비활성이면 스케줄 호출 시 예외가 전파되지 않는다 (예약 취소 경로)', () async {
      final repo = FakeReminderRepo(); // reminder_enabled 없음 → 비활성
      final service = ReviewReminderService(repo);

      await service.scheduleDailyReminder();
    });

    test('활성이면 스케줄 호출 시 예외가 전파되지 않는다 (예약 경로)', () async {
      final repo = FakeReminderRepo()..settings['reminder_enabled'] = 'true';
      final service = ReviewReminderService(repo);

      await service.scheduleDailyReminder();
    });

    test('cancelReminder는 예외를 전파하지 않는다', () async {
      final service = ReviewReminderService(FakeReminderRepo());

      await service.cancelReminder();
    });
  });
}
