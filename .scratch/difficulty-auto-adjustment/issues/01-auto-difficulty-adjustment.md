# 01 — 복습 결과 난이도 자동 반영 + 토글

Status: resolved

## 요구사항

복습 결과(정답/오답)가 단어 난이도에 자동 반영되어야 한다. MASTERED(난이도 ≤ 2)가 학습 성과를 반영하도록 함.

## 결정 사항

- 정책: 정답 -1, 오답 +1, 1~5 클램프 (단순 ±1 — 사용자 확인)
- 적용: `ReviewRepository.processReviewResult` 단일 진입점 — 퀴즈 4종·플래시카드·매칭 2종 모두 자동 적용
- 토글: `auto_difficulty` 설정 키 (기본 켬, `'false'`면 끔, 토글 UI는 설정 > ALGORITHM 탭) — "항상 적용"에서 사용자 요청으로 토글 추가
- 격리: 난이도 갱신은 2차 부수 효과 — try/catch로 실패를 무시하고, 리뷰카드 존재 여부와 독립 처리
- 매칭 일정 반영: 매칭 완료 시 퀴즈와 동일하게 `logReview` + `processReviewResult` + 업적 평가 호출 (선행 누락 해소)

## 구현

- `lib/features/words/data/models/word.dart` — `adjustedDifficultyForReview(isCorrect)` 순수 함수
- `lib/features/review/data/repositories/review_repository.dart` — `processReviewResult` 게이트 + `autoDifficultySettingKey` 상수
- `lib/features/settings/presentation/screens/settings_screen.dart` — `autoDifficultyEnabledProvider` + SwitchListTile 토글
- `lib/features/matching/presentation/screens/{word,grid}_matching_screen.dart` — logReview/processReviewResult/evaluateNow 추가
- `CONTEXT.md` — 난이도 정의에 자동 반영 정책 문서화

## 검증

- `flutter analyze` No issues
- `test/review_difficulty_test.dart` (DB 통합: ±1, 클램프, 경계, 토글 꺼짐/켜짐, 카드 없음)
- `test/model_test.dart` (단위: 정답/오답/클램프/불변성)
- 전체 `flutter test` 통과

## Comments

- (사용자) 토글 없이 항상 적용 → 설정 화면에서 끌 수 있는 토글로 변경 요청 → 반영.
- (리뷰) 난이도 갱신 비격리·카드 null 조기 반환 지적 → try/catch 격리 + 독립 처리로 수정.
- ADR 0004로 정책 기록 (`docs/adr/0004-difficulty-auto-adjustment.md`).
