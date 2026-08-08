import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../review/data/repositories/review_repository.dart';
import '../../review/presentation/screens/review_screen.dart';

/// 마스터 정원 기념일: 레벨 20 달성 날짜의 '돌'을 감지하고 축하 상태를 관리한다.
///
/// 플랫폼 제약(데스크톱/웹은 예약 알림 미지원) 때문에 앱 실행 중 감지 +
/// 인앱 축하 배너 방식으로 동작한다. 모바일에서는 시스템 알림도 시도된다.
class AnniversaryService {
  final ReviewRepository _reviewRepository;

  AnniversaryService(this._reviewRepository);

  /// 배지 달성 날짜 저장 키 (업적/대시보드가 함께 사용하는 단일 진실 원천)
  static const String badgeKey = 'master_garden_badge';

  /// 올해 기념일 축하를 이미 했는지 기록하는 키 (연도 단위로 갱신)
  static const String seenKey = 'anniversary_last_seen_year';

  /// 배지 달성 날짜 (YYYY-MM-DD → DateTime). 배지가 없으면 null.
  static DateTime? badgeDateFrom(String? badgeDate) {
    if (badgeDate == null) return null;
    return DateTime.tryParse(badgeDate);
  }

  /// 오늘이 배지 달성 기념일인지 확인한다.
  /// 조건: ① 달성 연도가 지났을 것(당일/당해 제외 — "1년 전 오늘" 문구용)
  ///       ② 월/일이 오늘과 일치할 것
  ///       ③ 올해 축하를 아직 완료하지 않았을 것
  /// [now]는 테스트에서 주입 가능한 현재 시각 (기본: 실제 현재).
  Future<bool> isAnniversaryToday({DateTime? now}) async {
    final badgeDate = await _reviewRepository.getSetting(badgeKey);
    final achieved = badgeDateFrom(badgeDate);
    if (achieved == null) return false;
    final current = now ?? DateTime.now();
    // 달성 연도에는 축하하지 않는다 (다음 해부터 '기념일').
    if (current.year <= achieved.year) return false;
    if (achieved.month != current.month || achieved.day != current.day) {
      return false;
    }
    final seen = await _reviewRepository.getSetting(seenKey);
    return seen != '${current.year}';
  }

  /// 올해 기념일 축하를 완료로 표시 (재표시 방지).
  Future<void> markAnniversaryCelebrated({DateTime? now}) async {
    final current = now ?? DateTime.now();
    await _reviewRepository.setSetting(seenKey, '${current.year}');
  }
}

final anniversaryServiceProvider = Provider<AnniversaryService>((ref) {
  final reviewRepository = ref.watch(reviewRepositoryProvider);
  return AnniversaryService(reviewRepository);
});

/// 오늘이 배지 기념일인지 (대시보드 배너 표시용).
final anniversaryTodayProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(anniversaryServiceProvider);
  return service.isAnniversaryToday();
});
