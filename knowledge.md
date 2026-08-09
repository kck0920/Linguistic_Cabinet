# Knowledge — VocaTree / Linguistic Cabinet

Flutter로 만든 크로스플랫폼(모바일/웹/데스크톱) 영어 단어장 앱. 단어 등록·복습·퀴즈·매칭으로 어휘 학습.

## Key code locations

- **Entry**: `lib/main.dart` → `lib/app.dart` → `lib/home/home_screen.dart`
- **State**: Riverpod (`flutter_riverpod`). **프로바이더는 화면 파일과 같은 파일에 정의** (별도 `providers/` 디렉토리 없음)
- **Storage**: SQLite via `DatabaseService` 싱글턴 (`lib/shared/services/database_service.dart`). 테이블: `words`, `review_cards`, `review_logs`, `settings`
- **Features**: `lib/features/<name>/` (data/models, data/repositories, presentation/screens, presentation/widgets)
  - `words/` — 모델, 리포, 목록/폼 화면, 단어 카드 위젯
  - `review/` — 복습 홈 + 플래시카드
  - `quiz/` — 퀴즈 종류 선택 + 4종 EXAM (뜻 맞추기/빈칸 채우기/뜻 타이핑/철자 타이핑)
  - `matching/` — 매칭 종류, 단어 매칭, 그리드 매칭
  - `settings/` — 캐비닛 모드, 복습 방식, 내보내기/가져오기, 전체 삭제, 통계, 리마인더·백업·홈 위젯 서비스
  - `achievements/` — 업적 서비스 3종(service/anniversary/evaluator) + 컬렉션·상세·토스트·수료증·가이드 화면
- **테마**: `lib/core/theme/` (app_theme.dart, app_colors.dart, cabinet_theme.dart, cabinet_colors.dart)
- **플랫폼 유틸**: `lib/core/utils/` — 조건부 export 방식(파일 3종: io/stub/web)으로 플랫폼별 구현 (file_picker, file_saver, platform_helper, url_launcher_helper, home_widget_helper, format_count)
- **도메인 용어**: `CONTEXT.md` (Ubiquitous Language). 단어/태그/난이도/복습/복습 카드/복습 로그 등 정식 용어 정의. 실제 코드 용어(ReviewCard·ReviewRepository·review_cards/review_logs) 기준 — ADR 0001의 "학습 세션/스케줄" 분리는 미채택

## Commands

Flutter SDK가 PATH에 없으면: `export PATH="$HOME/flutter/bin:$PATH"`

| Command | Purpose |
|---------|---------|
| `flutter pub get` | 의존성 설치 |
| `flutter analyze` | Lint + 타입체크 |
| `flutter test` | 테스트 실행 |
| `flutter build web --release` | 웹 릴리즈 빌드 (테스트용) |

**웹 dev server**: `cd build/web && python3 -m http.server 3001 --bind 0.0.0.0` → `http://localhost:3001`. `flutter run -d web-server`는 잘 죽으므로 정적 빌드 선호.

## Conventions & constraints

- **응답/주석/요약은 항상 한국어** (AGENTS.md 규칙)
- **DB 플랫폼 초기화가 최우선** (CRITICAL): 모든 DB 호출 전에 factory 초기화 필수
  - Web(`kIsWeb`): `databaseFactoryFfiWeb` (sqflite_common_ffi_web)
  - Desktop: `sqfliteFfiInit()` + `databaseFactoryFfi` (sqflite_common_ffi)
  - Mobile: 기본 `sqflite`
  - 참고: `lib/main.dart:9-15`, `database_service.dart:17-33`
- Riverpod 프로바이더는 화면 로컬 정의가 관례
- 이슈는 `.scratch/` 로컬 마크다운 파일로 관리 (docs/agents/issue-tracker.md)
- ADR: `docs/adr/` (예: 학습 용어 분리, 단어별 복습 방식 오버라이드, StudyLog 필드 확장, 복습 결과 난이도 자동 반영)

## Gotchas

- `file_picker`가 linux/macos/windows 기본 플러그인 경고 출력 — 무해
- 웹 빌드에서 `dart:html` 미지원 경고(file_picker/share_plus) — 런타임에 정상 동작
- `PLAN.md` 구조 트리는 실제 `lib/` 기준으로 갱신됨 — feature barrel 없음, 프로바이더는 화면 파일 로컬 정의
- `test/widget_test.dart`는 stub(runApp만 호출) — 테스트는 `sqflite_common_ffi`로 DB mock 필요
- 플랫폼별로 반드시 타깃에서 테스트할 것

## Current state / remaining work

완료된 주요 작업:
- **복습 결과 → 난이도 자동 반영** (정답 -1/오답 +1, 1~5 클램프) — `processReviewResult` 단일 진입점, `auto_difficulty` 설정 토글(기본 켬) (ADR 0004, CONTEXT.md 갱신)
- **mastered 업적 3종** (Mastered 50/200/500) — 복습/퀴즈/매칭 직후 자동 해금. 숙달 카운트는 `masteredCountProvider`(`ReviewRepository.getMasteredCount()`) 단일 진실 원천 (대시보드·설정·수료증 공용)
- **매칭도 학습 기록** — 완료 시 `logReview` + `processReviewResult`(SM-2 일정) + 업적 평가 (퀴즈와 동일)
- **LEDGER SUMMARY** — 홈 탭 복귀 시 `dashboardStatsProvider`·`streakDataProvider`·`masteredCountProvider` invalidate로 즉시 갱신. Mastered 타일 "N / M · X% 숙달" 표시 (설정 통계 탭도 동일 형식)
- **뜻 타이핑·철자 타이핑** 구현·테스트 완료 (`meaning_typing_screen.dart`·`spelling_typing_screen.dart`)
- **복습 알림 설정 UI + 시간 기반 예약** — 설정 > DATA 탭에 켜기/끄기 토글 + 시간 선택(showTimePicker). `scheduleDailyReminder()`가 지정 시간에 매일 반복 예약(`zonedSchedule` + `matchDateTimeComponents: DateTimeComponents.time`, flutter_local_notifications 22.1.0 named API). 앱 시작·백그라운드 복귀 시 예약 재구성. 예약 미지원 플랫폼(데스크톱/웹)은 앱 시작 시 즉시 알림이 폴백 (예약 ID: 즉시 0 / 예약 100)
- **홈 화면 위젯 (Android)** — 복습 대상 수·숙달 단어 수 2개 지표 표시. `home_widget` 0.9.3 + `HomeWidgetService`(스냅샷 저장·갱신, 조건부 export 헬퍼로 웹/데스크톱 무시) + 네이티브 `VocaTreeWidgetProvider`(HomeWidgetProvider)·위젯 XML 2종·Manifest receiver. 갱신 지점: 앱 시작·홈 탭 복귀(대시보드 리스너)·설정 가져오기/전체 삭제. iOS는 iOSName만 예비(macOS·iOS WidgetKit 확장은 미구현)
- **Android 빌드 수정** (최초 APK 검증에서 해결) — `compileSdk = 36` + core library desugaring(`desugar_jdk_libs 2.1.4`), `file_picker 10.3.10` 고정 (11.x는 AGP 9에서 Kotlin 미컴파일, 8.3.7은 compileSdk 34 하드코딩)
- **테스트 141개 (위젯) + 통합 테스트 1개** (LEDGER 타일/퀴즈·매칭 logReview, 통계 갱신, 난이도 반영 DB 통합, 업적 수여·토스트·컬렉션, 리마인더 서비스, 홈 위젯 스냅샷 등) — `flutter analyze` No issues
- **통합 테스트** — `integration_test/review_home_stats_flow_test.dart`: 실제 앱(main) + 인메모리 DB(`DatabaseService.setTestDatabaseInMemory`)로 복습→홈 탭 복귀 시 LEDGER SUMMARY 즉시 갱신 검증. 실행: `flutter test integration_test -d linux` (데스크톱 전용, 파일 DB 무영향)
- **성능 최적화** — 업적 수여 시 개별 `getSetting` ~52회 → `getSettings(keys)`(`WHERE key IN (...)`) 배치 1회로 (evaluateAndAward·getStatuses·evaluateAndGetStatuses 공용)

PLAN.md Phase 7~9 전 항목 구현 완료:
- 자동 백업: 구현 완료 (설정 토글 + 앱 시작/백그라운드 시 ZIP 저장)
- 복습 알림: 구현 완료 (위 항목) — 데스크톱/웹은 zonedSchedule 미지원으로 앱 시작 시 즉시 알림만 동작
- 이슈 트래커: `.scratch/difficulty-auto-adjustment/` (이슈 01~06, 완료 — 06은 PLAN.md·knowledge.md 문서 일관성)

## Key deps

flutter_riverpod, sqflite(+common_ffi, common_ffi_web), path_provider, path, uuid, file_picker(10.3.10 고정), share_plus, image, archive, flutter_markdown, google_fonts, flutter_local_notifications, timezone, home_widget, web, integration_test(sdk, dev)
