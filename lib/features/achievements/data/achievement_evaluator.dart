import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../review/presentation/screens/review_screen.dart';
import 'achievement_service.dart';
import 'models/achievement.dart';

/// 업적 평가 컨트롤러: 복습 완료·단어 추가·홈 복귀 등 이벤트 시 **즉시** 잔여
/// 업적을 평가·수여하고, 새로 해금된 업적을 토스트 오버레이 스트림으로 방출한다.
///
/// 앱 재시작이나 컬렉션 열람 없이도 해금이 실시간 반영되는 것이 목적.
class AchievementEvaluator {
  final Ref _ref;
  final _awardedController = StreamController<List<Achievement>>.broadcast();

  /// 직전 평가 시각 — 카드 연타 등 짧은 간격의 중복 평가를 막는다.
  DateTime? _lastEvaluatedAt;

  /// 연속 트리거를 흡수하는 쿨다운 간격.
  static const Duration cooldown = Duration(seconds: 3);

  AchievementEvaluator(this._ref);

  /// 새로 해금된 업적 스트림 (토스트 오버레이가 구독).
  Stream<List<Achievement>> get awardedStream => _awardedController.stream;

  /// 즉시 평가: 잔여 업적을 수여하고 해금 목록을 방출한다.
  /// 쿨다운 구간이거나 오류면 빈 목록을 반환한다 (호출부는 안전하게 무시).
  Future<List<Achievement>> evaluateNow() async {
    final now = DateTime.now();
    final last = _lastEvaluatedAt;
    if (last != null && now.difference(last) < cooldown) {
      return const [];
    }
    try {
      final repo = _ref.read(reviewRepositoryProvider);
      final awarded = await AchievementService(repo).evaluateAndAward();
      // 성공 시에만 쿨다운을 갱신한다 (실패 시 즉시 재시도 가능).
      _lastEvaluatedAt = now;
      if (awarded.isNotEmpty) {
        _ref.invalidate(achievementStatusesProvider);
        _ref.invalidate(masterGardenBadgeProvider);
        _awardedController.add(awarded);
      }
      return awarded;
    } catch (_) {
      // 평가 실패(DB 미초기화 등)는 치명적이지 않음
      return const [];
    }
  }

  void dispose() {
    _awardedController.close();
  }
}

final achievementEvaluatorProvider = Provider<AchievementEvaluator>((ref) {
  final evaluator = AchievementEvaluator(ref);
  ref.onDispose(evaluator.dispose);
  return evaluator;
});
