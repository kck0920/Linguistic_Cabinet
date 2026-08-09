import 'package:flutter_test/flutter_test.dart';
import 'package:linguistic_cabinet/core/theme/cabinet_colors.dart';
import 'package:linguistic_cabinet/features/achievements/data/achievement_service.dart';
import 'package:linguistic_cabinet/features/achievements/data/anniversary_service.dart';
import 'package:linguistic_cabinet/features/achievements/data/models/achievement.dart';
import 'package:linguistic_cabinet/features/review/data/repositories/review_repository.dart';

/// 평가용 가짜 리포: 통계를 메모리 값으로 주입한다.
/// [getSettingCalls]/[getSettingsCalls] 카운터로 개별 조회 vs 배치 조회를 검증한다.
class FakeAchievementRepo extends ReviewRepository {
  final Map<String, String> settings = {};
  int wordCount = 0;
  int masteredCount = 0;
  int streak = 0;
  Map<int, int> monthly = {};
  int getSettingCalls = 0;
  int getSettingsCalls = 0;

  @override
  Future<String?> getSetting(String key) async {
    getSettingCalls++;
    return settings[key];
  }

  @override
  Future<void> setSetting(String key, String value) async {
    settings[key] = value;
  }

  @override
  Future<Map<String, String>> getSettings(List<String> keys) async {
    getSettingsCalls++;
    return {
      for (final k in keys)
        if (settings[k] != null) k: settings[k]!,
    };
  }

  @override
  Future<Map<String, dynamic>> getReviewStats() async => {
        'totalWords': wordCount,
        'dueForReview': 0,
        'totalReviews': 0,
        'accuracy': 0,
      };

  @override
  Future<int> getMasteredCount() async => masteredCount;

  @override
  Future<int> getCurrentStreakDays() async => streak;

  @override
  Future<Map<int, int>> getMonthlyStudyDayCounts() async => monthly;
}

void main() {
  final now = DateTime(2026, 8, 7);

  group('AchievementService.evaluateAndAward', () {
    test('스트릭 25일이면 10·20일 업적만 수여한다 (30일은 미충족)', () async {
      final repo = FakeAchievementRepo()..streak = 25;
      final service = AchievementService(repo);

      final awarded = await service.evaluateAndAward(now: now);

      expect(awarded.length, 2);
      expect(
        awarded.map((a) => a.key),
        containsAll(['achv_streak_10', 'achv_streak_20']),
      );
      expect(repo.settings['achv_streak_10'], '2026-08-07');
      expect(repo.settings['achv_streak_20'], '2026-08-07');
      expect(repo.settings['achv_streak_30'], isNull);
    });

    test('월간 1월 22일 학습이면 January만 수여한다 (2월 5일은 미충족)', () async {
      final repo = FakeAchievementRepo()..monthly = {1: 22, 2: 5};
      final service = AchievementService(repo);

      final awarded = await service.evaluateAndAward(now: now);

      expect(awarded.length, 1);
      expect(awarded.single.key, 'achv_month_1');
      expect(repo.settings['achv_month_1'], isNotNull);
      expect(repo.settings['achv_month_2'], isNull);
    });

    test('월간 학습일은 연도 무관 최대치로 평가한다 (3월: 2025=15일, 2026=23일 → 23)', () async {
      final repo = FakeAchievementRepo()..monthly = {3: 23};
      final service = AchievementService(repo);

      final awarded = await service.evaluateAndAward(now: now);

      expect(repo.settings['achv_month_3'], isNotNull);
      expect(repo.settings['achv_month_4'], isNull);
      expect(awarded.length, 1);
    });

    test('단어 1,500개면 Collector 1000은 수여, 마스터(2,000)는 미수여', () async {
      final repo = FakeAchievementRepo()..wordCount = 1500;
      final service = AchievementService(repo);

      final awarded = await service.evaluateAndAward(now: now);

      expect(repo.settings['achv_first_word'], isNotNull);
      expect(repo.settings['achv_collector_100'], isNotNull);
      expect(repo.settings['achv_collector_1000'], isNotNull);
      expect(repo.settings[AnniversaryService.badgeKey], isNull);
      expect(awarded.length, 3);
    });

    test('이미 수여된 업적은 다시 수여하지 않는다', () async {
      final repo = FakeAchievementRepo()
        ..streak = 50
        ..settings['achv_streak_10'] = '2026-01-01';
      final service = AchievementService(repo);

      final awarded = await service.evaluateAndAward(now: now);

      // 10은 기존 값 유지, 20·30·40만 새로 수여
      expect(repo.settings['achv_streak_10'], '2026-01-01');
      expect(repo.settings['achv_streak_20'], '2026-08-07');
      expect(repo.settings['achv_streak_30'], '2026-08-07');
      expect(repo.settings['achv_streak_40'], '2026-08-07');
      expect(repo.settings['achv_streak_60'], isNull);
      expect(awarded.length, 3);
    });

    test('조건 미충족 시 아무것도 수여하지 않는다', () async {
      final repo = FakeAchievementRepo();
      final service = AchievementService(repo);

      final awarded = await service.evaluateAndAward(now: now);

      expect(awarded, isEmpty);
      expect(repo.settings, isEmpty);
    });

    test('스트릭 100일이면 모든 스트릭 업적(9개)이 수여된다 (경계)', () async {
      final repo = FakeAchievementRepo()..streak = 100;
      final service = AchievementService(repo);

      final awarded = await service.evaluateAndAward(now: now);

      expect(awarded.length, 9);
      for (final days in [10, 20, 30, 40, 60, 70, 80, 90, 100]) {
        expect(repo.settings['achv_streak_$days'], '2026-08-07',
            reason: 'Streak $days 미수여');
      }
    });

    test('월간 정확히 20일이면 수여된다 (>= 경계)', () async {
      final repo = FakeAchievementRepo()..monthly = {5: 20};
      final service = AchievementService(repo);

      final awarded = await service.evaluateAndAward(now: now);

      expect(awarded.length, 1);
      expect(repo.settings['achv_month_5'], isNotNull);
    });

    test('단어 정확히 100·1,000개 경계에서 각 단계가 수여된다', () async {
      final repo = FakeAchievementRepo()..wordCount = 1000;
      final service = AchievementService(repo);

      final awarded = await service.evaluateAndAward(now: now);

      expect(repo.settings['achv_collector_100'], isNotNull);
      expect(repo.settings['achv_collector_1000'], isNotNull);
      expect(repo.settings[AnniversaryService.badgeKey], isNull); // 2,000 미만
      expect(awarded.length, 3); // first_word + 100 + 1000
    });

    test('progressRingColor: 진행률 단계별 색상 경계값 (sepia)', () {
      final colors = CabinetColors.fromMode(CabinetThemeMode.sepia);

      // 0% → 회색 (ink3)
      expect(
        AchievementService.progressRingColor(0.0, colors),
        colors.ink3,
      );
      // 33% → 아직 회색 (34% 미만)
      expect(
        AchievementService.progressRingColor(0.33, colors),
        colors.ink3,
      );
      // 34% → 금색 (accent2) 경계
      expect(
        AchievementService.progressRingColor(0.34, colors),
        colors.accent2,
      );
      // 66% → 아직 금색
      expect(
        AchievementService.progressRingColor(0.66, colors),
        colors.accent2,
      );
      // 67% → 주황 (accent) 경계
      expect(
        AchievementService.progressRingColor(0.67, colors),
        colors.accent,
      );
      // 100% → 주황
      expect(
        AchievementService.progressRingColor(1.0, colors),
        colors.accent,
      );
    });

    test('progressRingColor: mono 테마에서도 3단계가 구분된다', () {
      final colors = CabinetColors.fromMode(CabinetThemeMode.mono);

      final gray = AchievementService.progressRingColor(0.0, colors);
      final mid = AchievementService.progressRingColor(0.5, colors);
      final hot = AchievementService.progressRingColor(1.0, colors);

      // 중간 단계는 mono에서 ink4(밝은 회색)로 구분된다
      expect(mid, colors.ink4);
      // 3개 색상이 모두 서로 달라야 단계가 시각적으로 구분된다
      expect({gray, mid, hot}.length, 3);
    });

    test('AchievementStatus.progress: 진행률 계산과 클램프', () {
      final streak10 = AchievementService.achievements
          .firstWhere((a) => a.key == 'achv_streak_10');
      final january = AchievementService.achievements
          .firstWhere((a) => a.key == 'achv_month_1');

      // 7 / 10 → 0.7
      expect(
        AchievementStatus(achievement: streak10, current: 7).progress,
        closeTo(0.7, 0.001),
      );
      // 15 / 20 → 0.75
      expect(
        AchievementStatus(achievement: january, current: 15).progress,
        closeTo(0.75, 0.001),
      );
      // 임계값 초과(22/20) → 1.0 고정
      expect(
        AchievementStatus(achievement: january, current: 22).progress,
        1.0,
      );
      // 진행 없음 → 0.0
      expect(
        AchievementStatus(achievement: streak10).progress,
        0.0,
      );
    });

    test('숙달 60단어면 Mastered 50만 수여한다 (200·500 미충족)', () async {
      final repo = FakeAchievementRepo()..masteredCount = 60;
      final service = AchievementService(repo);

      final awarded = await service.evaluateAndAward(now: now);

      expect(repo.settings['achv_mastered_50'], isNotNull);
      expect(repo.settings['achv_mastered_200'], isNull);
      expect(repo.settings['achv_mastered_500'], isNull);
      expect(awarded.length, 1);
    });

    test('숙달 500단어면 Mastered 50·200·500이 모두 수여된다 (경계)', () async {
      final repo = FakeAchievementRepo()..masteredCount = 500;
      final service = AchievementService(repo);

      final awarded = await service.evaluateAndAward(now: now);

      expect(repo.settings['achv_mastered_50'], isNotNull);
      expect(repo.settings['achv_mastered_200'], isNotNull);
      expect(repo.settings['achv_mastered_500'], isNotNull);
      expect(awarded.length, 3);
    });

    test('숙달 정확히 50단어면 Mastered 50이 수여된다 (>= 경계)', () async {
      final repo = FakeAchievementRepo()..masteredCount = 50;
      final service = AchievementService(repo);

      await service.evaluateAndAward(now: now);

      expect(repo.settings['achv_mastered_50'], isNotNull);
      expect(repo.settings['achv_mastered_200'], isNull);
    });

    test('업적 정의: 총 28개, 숙달 3개 + 스트릭 9개 + 월간 12개 구성', () {
      final all = AchievementService.achievements;
      expect(all.length, 28);
      expect(
        all.where((a) => a.category == AchievementCategory.mastered).length,
        3,
      );
      expect(
        all.where((a) => a.category == AchievementCategory.streak).length,
        9,
      );
      expect(
        all.where((a) => a.category == AchievementCategory.monthly).length,
        12,
      );
      expect(
        all.where((a) => a.category == AchievementCategory.monthly).every(
          (a) => a.month != null && a.threshold == 20,
        ),
        isTrue,
      );
    });

    test('수여 상태는 배치 조회(getSettings) 1회로 읽는다 (개별 getSetting 회피)',
        () async {
      final repo = FakeAchievementRepo()
        ..streak = 25
        ..settings['achv_streak_10'] = '2026-01-01';
      final service = AchievementService(repo);

      await service.evaluateAndAward(now: now);

      // 새로 수여된 업적은 저장된다.
      expect(repo.settings['achv_streak_20'], '2026-08-07');
      expect(repo.settings['achv_streak_30'], isNull); // 30 미충족
      // 기존 수여(10일)는 유지된다.
      expect(repo.settings['achv_streak_10'], '2026-01-01');
      // 배치 최적화 검증: 개별 getSetting 0회, getSettings 1회
      expect(repo.getSettingsCalls, 1);
      expect(repo.getSettingCalls, 0);
    });

    test('getStatuses도 배치 조회 1회만 사용한다', () async {
      final repo = FakeAchievementRepo()
        ..streak = 12
        ..settings['achv_streak_10'] = '2026-01-01';
      final service = AchievementService(repo);

      final statuses = await service.getStatuses();

      expect(statuses.length, 28);
      // 10일 업적은 기존 날짜 유지, 20일은 미충족
      expect(
        statuses
            .firstWhere((s) => s.achievement.key == 'achv_streak_10')
            .achievedOn,
        DateTime.parse('2026-01-01'),
      );
      expect(
        statuses
            .firstWhere((s) => s.achievement.key == 'achv_streak_20')
            .achievedOn,
        isNull,
      );
      expect(repo.getSettingsCalls, 1);
      expect(repo.getSettingCalls, 0);
    });
  });
}
