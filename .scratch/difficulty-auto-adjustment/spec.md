# 난이도 자동 반영 + mastered 업적

복습 결과가 단어 난이도(difficulty 1~5)에 자동 반영되어, MASTERED(난이도 ≤ 2)가 실제 학습 성과를 측정하는 동적 지표가 되는 기능 묶음.

## 배경

- MASTERED는 대시보드 LEDGER SUMMARY·설정 통계·마스터 정원 수료증의 핵심 지표지만, 기존에는 사용자 별점(단어 폼)에만 의존해 학습 성과가 숙달로 이어지지 않았음.
- 매칭 완료는 복습 로그·복습 일정에 아예 기록되지 않아 학습 성과에서 누락돼 있었음 (선행 작업).

## 결정 요약

| 항목 | 결정 |
|------|------|
| 난이도 조정 정책 | 정답 -1, 오답 +1, 1~5 클램프 (`Word.adjustedDifficultyForReview`) |
| 적용 지점 | `ReviewRepository.processReviewResult` 단일 진입점 (퀴즈 4종·플래시카드·매칭 2종) |
| 설정 토글 | `auto_difficulty` 키 (기본 켬, `'false'`면 끔) — 설정 화면 ALGORITHM 탭 |
| 부수 효과 격리 | 난이도 갱신 실패가 복습 기록 경로를 막지 않도록 try/catch 격리 + 카드 존재와 독립 |
| 정원/배지 | 레벨·마스터 정원 배지는 단어 수 기준 유지 (난이도 양방향 변동의 회귀 UX 방지) |
| mastered 업적 | Mastered 50 / 200 / 500 신설 (`AchievementCategory.mastered`) |
| 숙달 카운트 | `ReviewRepository.getMasteredCount()` (SQL: `difficulty <= 2`) |

## 참고 문서

- ADR: `docs/adr/0004-difficulty-auto-adjustment.md`
- 도메인 용어: `CONTEXT.md` 난이도(Difficulty) 항목
- 테스트: `test/review_difficulty_test.dart`, `test/model_test.dart`, `test/achievement_award_test.dart`, `test/achievement_collection_test.dart`, `test/achievement_toast_test.dart`

## 상태

- [x] 이슈 01 — 난이도 자동 반영 + 토글 + 매칭 일정 반영
- [x] 이슈 02 — mastered 업적 3종
- [x] 이슈 03 — 숙달 카운트 단일 진실 원천 통일 (`masteredCountProvider`)
- [x] 이슈 04 — 복습 알림 설정 UI + 시간 예약 (`zonedSchedule` 매일 반복)
- [x] 이슈 05 — 홈 화면 위젯 Android 전용 (복습 대상 수·숙달 수 표시, `home_widget` 0.9.3 + Android 빌드 수정)
- [x] 이슈 06 — PLAN.md·knowledge.md 문서 일관성 (구조 트리·의존성·완료 상태·상단 섹션 실제 구현 기준 재작성)
