import 'package:flutter/material.dart';

/// 업적 카테고리 (컬렉션 화면의 섹션 구분용).
enum AchievementCategory {
  /// 단어 수집 (First Word, Collector...)
  word,

  /// 연속 학습 (Streak 10~100)
  streak,

  /// 월간 도전 (각 달 20일 이상 학습)
  monthly,

  /// 마스터 (레벨 20 정원)
  master,
}

/// 업적 정의 (아이콘·이름·설명·조건 임계값 포함).
class Achievement {
  final String key; // settings 테이블 저장 키
  final String title;
  final String description;
  final IconData icon;
  final int threshold; // 조건 임계값 (단어 수 / 스트릭 일수 / 월 학습일 수)
  final Color color; // 해금 시 색상
  final AchievementCategory category;

  /// 월간 업적 전용: 대상 달 (1~12). 다른 카테고리는 null.
  final int? month;

  /// 진행 표시 단위 (단어 수 계열은 '단어', 그 외는 '일').
  String get progressUnit =>
      (category == AchievementCategory.word ||
              category == AchievementCategory.master)
          ? '단어'
          : '일';

  const Achievement({
    required this.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.threshold,
    required this.color,
    this.category = AchievementCategory.word,
    this.month,
  });
}

/// 업적 상태: 달성 여부 + 달성 날짜 + 현재 진행 값.
class AchievementStatus {
  final Achievement achievement;
  final DateTime? achievedOn;

  /// 현재 진행 값 (단어 수 / 현재 스트릭 / 해당 월 학습 일수).
  /// 미수여 카드의 프로그레스 바에 표시된다.
  final int current;

  const AchievementStatus({
    required this.achievement,
    this.achievedOn,
    this.current = 0,
  });

  bool get isEarned => achievedOn != null;

  /// 진행률 0~1 (임계값 도달·초과 시 1로 고정).
  double get progress => achievement.threshold <= 0
      ? 0
      : (current / achievement.threshold).clamp(0.0, 1.0);
}
