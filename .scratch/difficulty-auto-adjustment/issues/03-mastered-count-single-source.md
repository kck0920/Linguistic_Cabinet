# 03 — 숙달 카운트 단일 진실 원천 통일

Status: resolved

## 요구사항

숙달(Mastered) 단어 수를 계산하는 경로가 여럿이라 값이 어긋날(표류) 위험이 있음. 대시보드·설정·수료증의 인메모리 `words.where((w) => w.difficulty <= 2)` 계산을 `getMasteredCount()` 기반 단일 경로로 통일.

## 결정 사항

- 공용 프로바이더 `masteredCountProvider` 신설 — `ReviewRepository.getMasteredCount()`(SQL `difficulty <= 2`)의 단일 진실 원천.
- 3개 화면(대시보드·설정 통계·마스터 정원 수료증) 모두 인메모리 계산을 제거하고 프로바이더 watch로 교체.
- 최신성 보장: 홈 탭 복귀 리스너(대시보드)와 `_refreshAllProviders`(설정 — 가져오기/전체 삭제 후)에서 invalidate 추가.
- 로딩 순간 0 표시는 허용 가능한 트레이드오프 (홈 복귀 invalidate가 최신성 보장).

## 구현

- `lib/features/review/presentation/screens/review_screen.dart` — `masteredCountProvider` 정의 (3개 화면이 이미 `review_screen.dart`를 import — 추가 import 불필요)
- `lib/home/home_dashboard_screen.dart` — LEDGER 타일·정원 상태 텍스트 → 프로바이더, 홈 복귀 invalidate
- `lib/features/settings/presentation/screens/settings_screen.dart` — 통계 탭 MASTERED → 프로바이더, `_refreshAllProviders` invalidate
- `lib/features/achievements/presentation/master_garden_certificate_screen.dart` — MASTERED 통계 → 프로바이더

## 검증

- `flutter analyze` No issues
- `test/certificate_screen_test.dart` — `masteredCountProvider`를 단어 목록 기준으로 오버라이드
- `test/home_dashboard_ledger_test.dart` — `FakeLedgerRepository`에 `mastered` 필드 + `getMasteredCount` 오버라이드
- `test/master_garden_guide_test.dart` — Fake에 `getMasteredCount` 오버라이드 (수료증 내비게이션 실DB 접근 방지)
- 전체 `flutter test` 통과

## Comments

- (리뷰) `masteredCountProvider` 주석 오타("반영 반영" 중복) → 교정.
- (리뷰) 로딩 순간 0 표시 — 허용 가능한 트레이드오프로 확인.
