# 02 — mastered 업적 3종 (Mastered 50/200/500)

Status: resolved

## 요구사항

난이도 자동 조정과 마스터 정원을 연동. 마스터 정원 레벨·배지는 단어 수 기반(비회귀)으로 유지하되, mastered(난이도 ≤ 2)를 성취 체계로 승격.

## 결정 사항

- 정원 레벨·마스터 정원 배지: **단어 수 기준 유지** (난이도 양방향 변동을 레벨에 반영하면 회귀 UX — "단어를 틀렸더니 정원이 시든다")
- mastered 업적 3종 신설: Mastered 50 / 200 / 500 (`AchievementCategory.mastered` 신설)
- 업적은 달성 날짜 영구 저장이라 회귀·토글 공정성 문제 없음 (토글 꺼짐 시에도 별점 기반 숙달로 동작)
- 숙달 카운트는 SQL 단일 쿼리: `ReviewRepository.getMasteredCount()`

## 구현

- `lib/features/achievements/data/models/achievement.dart` — `AchievementCategory.mastered` + `progressUnit` '단어'
- `lib/features/review/data/repositories/review_repository.dart` — `getMasteredCount()` (SQL `difficulty <= 2`)
- `lib/features/achievements/data/achievement_service.dart` — Mastered 50/200/500 정의, `_currentMetrics`에 masteredCount, `AchievementMetrics` typedef, `currentFor`/`categoryLabel` 분기
- `lib/features/achievements/presentation/achievement_collection_screen.dart` — 'MASTERED WORDS · 단어 숙달' 섹션 (수집 다음)

## 검증

- `flutter analyze` No issues
- `test/achievement_award_test.dart` (숙달 60→50만, 500→3종, 50 경계, 총 28개 구성)
- `test/achievement_collection_test.dart` (1/28, 링 28, 잠금 27, 숙달 섹션)
- `test/achievement_toast_test.dart` / `test/helpers.dart` — Fake에 `getMasteredCount` 오버라이드 (실DB 접근 방지)
- `test/review_difficulty_test.dart` — `getMasteredCount` DB 테스트
- 전체 `flutter test` 통과

## Comments

- (사용자) 마스터 정원 연동 방향 → "mastered 업적 추가 (권장)" 선택.
- (리뷰) 목록 순서 주석 스테일 + 메트릭 레코드 타입 중복 → 주석 수정 + `AchievementMetrics` typedef 추출.
