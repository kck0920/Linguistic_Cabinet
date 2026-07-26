import 'package:uuid/uuid.dart';

enum ReviewMethod {
  linear,
  fixed,
  sm2, // SM-2 간격 반복 알고리즘
}

class ReviewCard {
  final String id;
  final String wordId;
  final ReviewMethod reviewMethod;
  final ReviewMethod? overrideMethod; // 단어별 복습 방식 오버라이드
  final int? fixedIntervalDays;
  final DateTime nextReviewDate;
  final int reviewCount;
  final DateTime createdAt;
  
  // SM-2 알고리즘 필드
  final double easinessFactor; // 난이도 계수 (1.3 ~ 5.0)
  final int interval;         // 다음 복습까지의 일수
  final int repetition;       // 연속 정답 횟수

  /// 실제 사용되는 복습 방식 (오버라이드 우선)
  ReviewMethod get activeMethod => overrideMethod ?? reviewMethod;

  ReviewCard({
    String? id,
    required this.wordId,
    required this.reviewMethod,
    this.overrideMethod,
    this.fixedIntervalDays,
    required this.nextReviewDate,
    this.reviewCount = 0,
    DateTime? createdAt,
    this.easinessFactor = 2.5, // SM-2 기본값
    this.interval = 0,
    this.repetition = 0,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  // Linear schedule: 1 -> 3 -> 7 -> 30 days
  static const List<int> linearSchedule = [1, 3, 7, 30];

  DateTime getNextReviewDate() {
    final active = activeMethod;
    if (active == ReviewMethod.fixed && fixedIntervalDays != null) {
      return DateTime.now().add(Duration(days: fixedIntervalDays!));
    }
    
    if (active == ReviewMethod.sm2) {
      return DateTime.now().add(Duration(days: interval));
    }
    
    // Linear method
    final scheduleIndex = reviewCount.clamp(0, linearSchedule.length - 1);
    final daysToAdd = linearSchedule[scheduleIndex];
    return DateTime.now().add(Duration(days: daysToAdd));
  }

  ReviewCard incrementReviewCount() {
    return ReviewCard(
      id: id,
      wordId: wordId,
      reviewMethod: reviewMethod,
      overrideMethod: overrideMethod,
      fixedIntervalDays: fixedIntervalDays,
      nextReviewDate: getNextReviewDate(),
      reviewCount: reviewCount + 1,
      createdAt: createdAt,
      easinessFactor: easinessFactor,
      interval: interval,
      repetition: repetition,
    );
  }

  /// SM-2 알고리즘에 따라 복습 결과를 반영하여 새 ReviewCard 반환
  /// quality: 0-5 (0=가장 나쁨, 5=가장 좋음)
  ReviewCard updateWithSM2(int quality) {
    // quality는 0-5 사이로 제한
    final q = quality.clamp(0, 5);
    
    //新的 easinessFactor 계산
    final newEF = easinessFactor + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02));
    final clampedEF = newEF < 1.3 ? 1.3 : newEF;
    
    int newRepetition;
    int newInterval;
    
    if (q < 3) {
      // 틀린 경우: 반복 횟수 초기화, 간격 초기화
      newRepetition = 0;
      newInterval = 1;
    } else {
      // 맞춘 경우: 반복 횟수 증가, 간격 증가
      newRepetition = repetition + 1;
      
      if (newRepetition == 1) {
        newInterval = 1;
      } else if (newRepetition == 2) {
        newInterval = 6;
      } else {
        newInterval = (interval * clampedEF).round();
      }
    }
    
    return ReviewCard(
      id: id,
      wordId: wordId,
      reviewMethod: reviewMethod,
      overrideMethod: overrideMethod,
      fixedIntervalDays: fixedIntervalDays,
      nextReviewDate: DateTime.now().add(Duration(days: newInterval)),
      reviewCount: reviewCount + 1,
      createdAt: createdAt,
      easinessFactor: clampedEF,
      interval: newInterval,
      repetition: newRepetition,
    );
  }

  bool get isDueForReview {
    return DateTime.now().isAfter(nextReviewDate) || 
           DateTime.now().isAtSameMomentAs(nextReviewDate);
  }

  Map<String, dynamic> toMap() {
    String methodStr;
    switch (reviewMethod) {
      case ReviewMethod.linear:
        methodStr = 'linear';
        break;
      case ReviewMethod.fixed:
        methodStr = 'fixed';
        break;
      case ReviewMethod.sm2:
        methodStr = 'sm2';
        break;
    }
    
    String? overrideMethodStr;
    if (overrideMethod != null) {
      switch (overrideMethod!) {
        case ReviewMethod.linear:
          overrideMethodStr = 'linear';
          break;
        case ReviewMethod.fixed:
          overrideMethodStr = 'fixed';
          break;
        case ReviewMethod.sm2:
          overrideMethodStr = 'sm2';
          break;
      }
    }
    
    return {
      'id': id,
      'word_id': wordId,
      'review_method': methodStr,
      'override_method': overrideMethodStr,
      'fixed_interval_days': fixedIntervalDays,
      'next_review_date': nextReviewDate.toIso8601String(),
      'review_count': reviewCount,
      'created_at': createdAt.toIso8601String(),
      'easiness_factor': easinessFactor,
      'interval': interval,
      'repetition': repetition,
    };
  }

  factory ReviewCard.fromMap(Map<String, dynamic> map) {
    ReviewMethod method;
    switch (map['review_method']) {
      case 'linear':
        method = ReviewMethod.linear;
        break;
      case 'fixed':
        method = ReviewMethod.fixed;
        break;
      case 'sm2':
        method = ReviewMethod.sm2;
        break;
      default:
        method = ReviewMethod.linear;
    }

    ReviewMethod? overrideMethod;
    switch (map['override_method']) {
      case 'linear':
        overrideMethod = ReviewMethod.linear;
        break;
      case 'fixed':
        overrideMethod = ReviewMethod.fixed;
        break;
      case 'sm2':
        overrideMethod = ReviewMethod.sm2;
        break;
    }
    
    return ReviewCard(
      id: map['id'],
      wordId: map['word_id'],
      reviewMethod: method,
      overrideMethod: overrideMethod,
      fixedIntervalDays: map['fixed_interval_days'],
      nextReviewDate: DateTime.parse(map['next_review_date']),
      reviewCount: map['review_count'] ?? 0,
      createdAt: DateTime.parse(map['created_at']),
      easinessFactor: (map['easiness_factor'] as num?)?.toDouble() ?? 2.5,
      interval: map['interval'] ?? 0,
      repetition: map['repetition'] ?? 0,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReviewCard && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ReviewCard(id: $id, wordId: $wordId, method: $reviewMethod, nextReview: $nextReviewDate)';
  }
}
