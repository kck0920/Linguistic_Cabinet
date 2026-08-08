import 'package:flutter_test/flutter_test.dart';
import 'package:linguistic_cabinet/features/achievements/data/anniversary_service.dart';
import 'package:linguistic_cabinet/features/review/data/repositories/review_repository.dart';

/// settings 맵 기반 가짜 리포 (master_badge_test와 동일 패턴)
class FakeSettingsRepository extends ReviewRepository {
  final Map<String, String> settings = {};

  @override
  Future<String?> getSetting(String key) async => settings[key];

  @override
  Future<void> setSetting(String key, String value) async {
    settings[key] = value;
  }
}

String _dateOf(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

void main() {
  group('AnniversaryService.기념일 계산', () {
    test('badgeDateFrom: 배지 날짜를 DateTime으로 파싱한다', () {
      final d = AnniversaryService.badgeDateFrom('2026-08-07');
      expect(d, isNotNull);
      expect(d!.year, 2026);
      expect(d.month, 8);
      expect(d.day, 7);
    });

    test('badgeDateFrom: 배지가 없거나 잘못된 형식이면 null', () {
      expect(AnniversaryService.badgeDateFrom(null), isNull);
      expect(AnniversaryService.badgeDateFrom('not-a-date'), isNull);
    });
  });

  group('AnniversaryService.감지/축하 상태 (now 주입)', () {
    // 기준 시각: 2026-08-07 (테스트 고정 — DateTime.now 의존 제거)
    final now = DateTime(2026, 8, 7, 10, 0);

    test('지난해 같은 월/일이면 true (기념일)', () async {
      final repo = FakeSettingsRepository();
      await repo.setSetting(
        AnniversaryService.badgeKey,
        _dateOf(DateTime(2025, 8, 7)), // 1년 전 오늘
      );

      final service = AnniversaryService(repo);
      expect(await service.isAnniversaryToday(now: now), isTrue);
    });

    test('달성 연도(당일 포함)에는 false — "1년 전" 문구 방지', () async {
      final repo = FakeSettingsRepository();
      // 오늘이 달성일이어도 같은 연도이므로 아직 기념일이 아니다.
      await repo.setSetting(AnniversaryService.badgeKey, _dateOf(now));

      final service = AnniversaryService(repo);
      expect(await service.isAnniversaryToday(now: now), isFalse);
    });

    test('달성 월/일이 오늘과 다르면 false', () async {
      final repo = FakeSettingsRepository();
      // 1년 전이지만 월이 다른 날짜
      await repo.setSetting(
        AnniversaryService.badgeKey,
        _dateOf(DateTime(2025, 9, 7)),
      );

      final service = AnniversaryService(repo);
      expect(await service.isAnniversaryToday(now: now), isFalse);
    });

    test('배지가 없으면 false', () async {
      final repo = FakeSettingsRepository();
      final service = AnniversaryService(repo);
      expect(await service.isAnniversaryToday(now: now), isFalse);
    });

    test('올해 이미 축하했으면 false (연간 1회)', () async {
      final repo = FakeSettingsRepository();
      await repo.setSetting(
        AnniversaryService.badgeKey,
        _dateOf(DateTime(2025, 8, 7)),
      );

      final service = AnniversaryService(repo);
      expect(await service.isAnniversaryToday(now: now), isTrue);

      await service.markAnniversaryCelebrated(now: now);
      expect(await service.isAnniversaryToday(now: now), isFalse);
    });

    test('markAnniversaryCelebrated는 기준 연도를 기록한다', () async {
      final repo = FakeSettingsRepository();
      final service = AnniversaryService(repo);
      await service.markAnniversaryCelebrated(now: now);
      expect(
        await repo.getSetting(AnniversaryService.seenKey),
        '2026',
      );
    });
  });
}
