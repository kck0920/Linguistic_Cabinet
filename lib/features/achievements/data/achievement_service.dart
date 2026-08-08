import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/cabinet_colors.dart';
import '../../../core/utils/format_count.dart' as format_util;
import '../../review/data/repositories/review_repository.dart';
import '../../review/presentation/screens/review_screen.dart';
import 'anniversary_service.dart';
import 'models/achievement.dart';

/// 마스터 정원 기념 배지: 레벨 20(2,000단어) 달성 날짜(YYYY-MM-DD) 또는 null.
/// 달성 시 settings 테이블에 영구 저장되어 앱을 재시작해도 유지된다.
/// (배지 로직의 단일 진실 원천: 업적/수료증/대시보드가 모두 이 프로바이더를 사용)
final masterGardenBadgeProvider = FutureProvider<String?>((ref) async {
  final repo = ref.watch(reviewRepositoryProvider);
  return repo.getSetting(AnniversaryService.badgeKey);
});

/// 업적 상태 목록 (컬렉션 화면·평가 컨트롤러가 함께 사용).
/// 열람 시 잔여 업적을 먼저 평가·수여한다 (자가치유, 지표 1회 조회).
final achievementStatusesProvider = FutureProvider<List<AchievementStatus>>(
  (ref) async {
    final repo = ref.watch(reviewRepositoryProvider);
    return AchievementService(repo).evaluateAndGetStatuses();
  },
);

/// 업적 컬렉션 정의: 모든 업적의 단일 진실 원천.
class AchievementService {
  final ReviewRepository _reviewRepository;

  AchievementService(this._reviewRepository);

  /// 월간 업적 공통 임계값: 해당 달에 20일 이상 학습
  static const int monthlyThreshold = 20;

  /// 업적 정의 목록 (항상 이 순서로 표시된다: 수집 → 스트릭 → 월간 → 마스터).
  static const List<Achievement> achievements = [
    // ── 단어 수집 ─────────────────────────────────────────────────
    Achievement(
      key: 'achv_first_word',
      title: 'First Word',
      description: '첫 단어를 수집하세요',
      icon: Icons.eco_outlined,
      threshold: 1,
      color: Color(0xFF4A6B3A),
      category: AchievementCategory.word,
    ),
    Achievement(
      key: 'achv_collector_100',
      title: 'Collector 100',
      description: '100개의 단어를 수집하세요',
      icon: Icons.inventory_2_outlined,
      threshold: 100,
      color: Color(0xFF33556E),
      category: AchievementCategory.word,
    ),
    Achievement(
      key: 'achv_collector_1000',
      title: 'Collector 1000',
      description: '1,000개의 단어를 수집하세요',
      icon: Icons.auto_stories_outlined,
      threshold: 1000,
      color: Color(0xFF6F5A44),
      category: AchievementCategory.word,
    ),

    // ── 연속 학습 (스트릭) ─────────────────────────────────────────
    Achievement(
      key: 'achv_streak_10',
      title: 'Streak 10',
      description: '10일 연속 학습',
      icon: Icons.local_fire_department_outlined,
      threshold: 10,
      color: Color(0xFFB8562D),
      category: AchievementCategory.streak,
    ),
    Achievement(
      key: 'achv_streak_20',
      title: 'Streak 20',
      description: '20일 연속 학습',
      icon: Icons.local_fire_department_outlined,
      threshold: 20,
      color: Color(0xFFB8562D),
      category: AchievementCategory.streak,
    ),
    Achievement(
      key: 'achv_streak_30',
      title: 'Streak 30',
      description: '30일 연속 학습',
      icon: Icons.local_fire_department_outlined,
      threshold: 30,
      color: Color(0xFFB8562D),
      category: AchievementCategory.streak,
    ),
    Achievement(
      key: 'achv_streak_40',
      title: 'Streak 40',
      description: '40일 연속 학습',
      icon: Icons.local_fire_department_outlined,
      threshold: 40,
      color: Color(0xFFB8562D),
      category: AchievementCategory.streak,
    ),
    Achievement(
      key: 'achv_streak_60',
      title: 'Streak 60',
      description: '60일 연속 학습',
      icon: Icons.local_fire_department_outlined,
      threshold: 60,
      color: Color(0xFFB8562D),
      category: AchievementCategory.streak,
    ),
    Achievement(
      key: 'achv_streak_70',
      title: 'Streak 70',
      description: '70일 연속 학습',
      icon: Icons.local_fire_department_outlined,
      threshold: 70,
      color: Color(0xFFB8562D),
      category: AchievementCategory.streak,
    ),
    Achievement(
      key: 'achv_streak_80',
      title: 'Streak 80',
      description: '80일 연속 학습',
      icon: Icons.local_fire_department_outlined,
      threshold: 80,
      color: Color(0xFFB8562D),
      category: AchievementCategory.streak,
    ),
    Achievement(
      key: 'achv_streak_90',
      title: 'Streak 90',
      description: '90일 연속 학습',
      icon: Icons.local_fire_department_outlined,
      threshold: 90,
      color: Color(0xFFB8562D),
      category: AchievementCategory.streak,
    ),
    Achievement(
      key: 'achv_streak_100',
      title: 'Streak 100',
      description: '100일 연속 학습',
      icon: Icons.local_fire_department_outlined,
      threshold: 100,
      color: Color(0xFFB8562D),
      category: AchievementCategory.streak,
    ),

    // ── 월간 도전 (각 달 20일 이상 학습) ───────────────────────────
    // 주의: 아래 설명문의 '20일'은 [monthlyThreshold]와 동기화해야 한다
    // (const 리스트라 보간 대신 리터럴 사용).
    Achievement(
      key: 'achv_month_1',
      title: 'January Study',
      description: '1월에 20일 이상 학습',
      icon: Icons.calendar_month_outlined,
      threshold: monthlyThreshold,
      color: Color(0xFF4A6B8A),
      category: AchievementCategory.monthly,
      month: 1,
    ),
    Achievement(
      key: 'achv_month_2',
      title: 'February Study',
      description: '2월에 20일 이상 학습',
      icon: Icons.calendar_month_outlined,
      threshold: monthlyThreshold,
      color: Color(0xFF4A6B8A),
      category: AchievementCategory.monthly,
      month: 2,
    ),
    Achievement(
      key: 'achv_month_3',
      title: 'March Study',
      description: '3월에 20일 이상 학습',
      icon: Icons.calendar_month_outlined,
      threshold: monthlyThreshold,
      color: Color(0xFF4A6B8A),
      category: AchievementCategory.monthly,
      month: 3,
    ),
    Achievement(
      key: 'achv_month_4',
      title: 'April Study',
      description: '4월에 20일 이상 학습',
      icon: Icons.calendar_month_outlined,
      threshold: monthlyThreshold,
      color: Color(0xFF3D7A5A),
      category: AchievementCategory.monthly,
      month: 4,
    ),
    Achievement(
      key: 'achv_month_5',
      title: 'May Study',
      description: '5월에 20일 이상 학습',
      icon: Icons.calendar_month_outlined,
      threshold: monthlyThreshold,
      color: Color(0xFF3D7A5A),
      category: AchievementCategory.monthly,
      month: 5,
    ),
    Achievement(
      key: 'achv_month_6',
      title: 'June Study',
      description: '6월에 20일 이상 학습',
      icon: Icons.calendar_month_outlined,
      threshold: monthlyThreshold,
      color: Color(0xFF3D7A5A),
      category: AchievementCategory.monthly,
      month: 6,
    ),
    Achievement(
      key: 'achv_month_7',
      title: 'July Study',
      description: '7월에 20일 이상 학습',
      icon: Icons.calendar_month_outlined,
      threshold: monthlyThreshold,
      color: Color(0xFFC07A3A),
      category: AchievementCategory.monthly,
      month: 7,
    ),
    Achievement(
      key: 'achv_month_8',
      title: 'August Study',
      description: '8월에 20일 이상 학습',
      icon: Icons.calendar_month_outlined,
      threshold: monthlyThreshold,
      color: Color(0xFFC07A3A),
      category: AchievementCategory.monthly,
      month: 8,
    ),
    Achievement(
      key: 'achv_month_9',
      title: 'September Study',
      description: '9월에 20일 이상 학습',
      icon: Icons.calendar_month_outlined,
      threshold: monthlyThreshold,
      color: Color(0xFFC07A3A),
      category: AchievementCategory.monthly,
      month: 9,
    ),
    Achievement(
      key: 'achv_month_10',
      title: 'October Study',
      description: '10월에 20일 이상 학습',
      icon: Icons.calendar_month_outlined,
      threshold: monthlyThreshold,
      color: Color(0xFF8A6B4A),
      category: AchievementCategory.monthly,
      month: 10,
    ),
    Achievement(
      key: 'achv_month_11',
      title: 'November Study',
      description: '11월에 20일 이상 학습',
      icon: Icons.calendar_month_outlined,
      threshold: monthlyThreshold,
      color: Color(0xFF8A6B4A),
      category: AchievementCategory.monthly,
      month: 11,
    ),
    Achievement(
      key: 'achv_month_12',
      title: 'December Study',
      description: '12월에 20일 이상 학습',
      icon: Icons.calendar_month_outlined,
      threshold: monthlyThreshold,
      color: Color(0xFF8A6B4A),
      category: AchievementCategory.monthly,
      month: 12,
    ),

    // ── 마스터 ─────────────────────────────────────────────────────
    Achievement(
      // 기념일/대시보드와 동일한 키를 사용 (단일 진실 원천)
      key: AnniversaryService.badgeKey,
      title: 'Master Gardener',
      description: '2,000단어를 모아 정원을 만개시키세요',
      icon: Icons.emoji_events,
      threshold: 2000,
      color: Color(0xFFB8562D),
      category: AchievementCategory.master,
    ),
  ];

  /// 업적 평가에 필요한 현재 지표를 한 번에 조회한다.
  /// (단어 수·현재 스트릭·연도 무관 월별 최대 학습일)
  Future<({int totalWords, int streak, Map<int, int> monthly})>
      _currentMetrics() async {
    final stats = await _reviewRepository.getReviewStats();
    final totalWords = stats['totalWords'] as int? ?? 0;
    final streak = await _reviewRepository.getCurrentStreakDays();
    final monthly = await _reviewRepository.getMonthlyStudyDayCounts();
    return (totalWords: totalWords, streak: streak, monthly: monthly);
  }

  /// 카테고리 표시 라벨 (컬렉션 섹션·상세 화면 공용 — 단일 진실 원천).
  static String categoryLabel(AchievementCategory category) {
    switch (category) {
      case AchievementCategory.word:
        return 'COLLECTED WORDS · 단어 수집';
      case AchievementCategory.streak:
        return 'STREAK · 연속 학습';
      case AchievementCategory.monthly:
        return 'MONTHLY CHALLENGE · 월간 도전';
      case AchievementCategory.master:
        return 'MASTER · 정원';
    }
  }

  /// 미해금 배지 진행 링의 단계별 색상 (달아오르는 시각 피드백).
  /// 로직은 [CabinetColors.progressHeat]에 위임 (대시보드 배지 카드와 공용).
  static Color progressRingColor(double progress, CabinetColors colors) =>
      colors.progressHeat(progress);

  /// 천 단위 쉼표 포맷 (1,200 / 2,000단어).
  /// 로직은 [formatCount] 공용 헬퍼에 위임 (배지 카드 등과 단일 진실 원천).
  static String formatCount(int n) => format_util.formatCount(n);

  /// 카테고리별 현재 진행 값 (단어 수 / 스트릭 / 해당 월 학습일).
  /// 수여 판정·프로그레스 표시가 같은 매핑을 사용하도록 단일화.
  static int currentFor(
    Achievement a, {
    required int totalWords,
    required int streak,
    required Map<int, int> monthly,
  }) {
    switch (a.category) {
      case AchievementCategory.word:
      case AchievementCategory.master:
        return totalWords;
      case AchievementCategory.streak:
        return streak;
      case AchievementCategory.monthly:
        return monthly[a.month] ?? 0;
    }
  }

  static String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// 저장된 모든 업적 날짜를 읽어 상태 목록을 만든다.
  /// 각 상태에는 현재 진행 값([AchievementStatus.current])이 포함된다
  /// (카드의 프로그레스 바 표시용). [metrics]를 주면 재조회를 건너뛴다.
  Future<List<AchievementStatus>> getStatuses({
    ({int totalWords, int streak, Map<int, int> monthly})? metrics,
  }) async {
    final m = metrics ?? await _currentMetrics();
    final statuses = <AchievementStatus>[];
    for (final a in achievements) {
      final dateStr = await _reviewRepository.getSetting(a.key);
      statuses.add(AchievementStatus(
        achievement: a,
        achievedOn: dateStr != null ? DateTime.tryParse(dateStr) : null,
        current: currentFor(
          a,
          totalWords: m.totalWords,
          streak: m.streak,
          monthly: m.monthly,
        ),
      ));
    }
    return statuses;
  }

  /// 업적 달성 저장 (이미 있으면 스킵). 저장했으면 true 반환.
  Future<bool> awardIfNotEarned(String key, DateTime date) async {
    final existing = await _reviewRepository.getSetting(key);
    if (existing != null) return false;
    await _reviewRepository.setSetting(key, _dateStr(date));
    return true;
  }

  /// 현재 상태(단어 수·스트릭·월별 학습일)를 평가해 조건을 충족한
  /// 미수여 업적을 모두 수여하고, **이번에 새로 수여된 업적 목록**을 반환.
  /// (앱 시작·홈 복귀 시 호출되어 잔여 업적을 자가치유하고,
  ///  반환 목록은 해금 축하 토스트에 사용된다)
  Future<List<Achievement>> evaluateAndAward({DateTime? now}) async {
    final current = now ?? DateTime.now();
    final m = await _currentMetrics();
    final awarded = <Achievement>[];
    for (final a in achievements) {
      // awardIfNotEarned가 이미 수여 여부를 확인하므로 (중복 수여 방지)
      // 여기서는 조건 충족 여부만 평가하고 수여는 서비스에 위임한다.
      final progressValue = currentFor(
        a,
        totalWords: m.totalWords,
        streak: m.streak,
        monthly: m.monthly,
      );
      if (progressValue >= a.threshold &&
          await awardIfNotEarned(a.key, current)) {
        awarded.add(a);
      }
    }
    return awarded;
  }

  /// 잔여 업적 평가·수여 + 상태 목록 반환을 한 번의 지표 조회로 수행.
  /// (컬렉션 화면용 — evaluateAndAward + getStatuses의 중복 조회 방지)
  Future<List<AchievementStatus>> evaluateAndGetStatuses({DateTime? now}) async {
    final m = await _currentMetrics();
    final current = now ?? DateTime.now();
    final statuses = <AchievementStatus>[];
    for (final a in achievements) {
      final progressValue = currentFor(
        a,
        totalWords: m.totalWords,
        streak: m.streak,
        monthly: m.monthly,
      );
      var dateStr = await _reviewRepository.getSetting(a.key);
      if (dateStr == null && progressValue >= a.threshold) {
        if (await awardIfNotEarned(a.key, current)) {
          dateStr = _dateStr(current);
        }
      }
      statuses.add(AchievementStatus(
        achievement: a,
        achievedOn: dateStr != null ? DateTime.tryParse(dateStr) : null,
        current: progressValue,
      ));
    }
    return statuses;
  }
}
