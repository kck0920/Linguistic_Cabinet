# Knowledge — VocaTree / Linguistic Cabinet

Flutter로 만든 크로스플랫폼(모바일/웹/데스크톱) 영어 단어장 앱. 단어 등록·복습·퀴즈·매칭으로 어휘 학습.

## Key code locations

- **Entry**: `lib/main.dart` → `lib/app.dart` → `lib/home/home_screen.dart`
- **State**: Riverpod (`flutter_riverpod`). **프로바이더는 화면 파일과 같은 파일에 정의** (별도 `providers/` 디렉토리 없음)
- **Storage**: SQLite via `DatabaseService` 싱글턴 (`lib/shared/services/database_service.dart`). 테이블: `words`, `review_cards`, `review_logs`, `settings`
- **Features**: `lib/features/<name>/` (data/models, data/repositories, presentation/screens, presentation/widgets)
  - `words/` — 모델, 리포, 목록/폼 화면, 단어 카드 위젯
  - `review/` — 복습 홈 + 플래시카드
  - `quiz/` — 퀴즈 종류 선택, 뜻 퀴즈, 빈칸 채우기
  - `matching/` — 매칭 종류, 단어 매칭, 그리드 매칭
  - `settings/` — 다크모드, 복습 방식, 내보내기/가져오기, 전체 삭제
- **테마**: `lib/core/theme/` (app_theme.dart, app_colors.dart, cabinet_theme.dart, cabinet_colors.dart)
- **플랫폼 유틸**: `lib/core/utils/` — 조건부 export 방식(파일 3종: io/stub/web)으로 플랫폼별 구현 (file_picker, file_saver, platform_helper, url_launcher_helper)
- **도메인 용어**: `CONTEXT.md` (Ubiquitous Language). 단어/태그/학습 세션/학습 스케줄 등 정식 용어 정의, "복습/review" 같은 용어 회피 규칙 있음

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
- ADR: `docs/adr/` (예: 학습 용어 분리, 단어별 복습 방식 오버라이드, StudyLog 필드 확장)

## Gotchas

- `file_picker`가 linux/macos/windows 기본 플러그인 경고 출력 — 무해
- 웹 빌드에서 `dart:html` 미지원 경고(file_picker/share_plus) — 런타임에 정상 동작
- `PLAN.md`의 구조 트리 중 실제로 없는 경로 있음 (feature barrel, `shared/widgets/` 없음) — PLAN.md는 계획 문서, 실제 구조는 위 Key code locations 기준
- `test/widget_test.dart`는 stub(runApp만 호출) — 테스트는 `sqflite_common_ffi`로 DB mock 필요
- 플랫폼별로 반드시 타깃에서 테스트할 것

## Current state / remaining work

PLAN.md Phase 7-9 중 미구현:
- 뜻 타이핑(MeaningTyping), 철자 타이핑(SpellingTyping) — 단, `spelling_typing_screen.dart`·`meaning_typing_screen.dart` 파일은 이미 존재
- 자동 백업, 로컬 알림, 홈 위젯
- 본격적인 테스트 (Phase 9)

## Key deps

flutter_riverpod, sqflite(+common_ffi, common_ffi_web), path_provider, uuid, file_picker, share_plus, image, archive, flutter_markdown, google_fonts, flutter_local_notifications, web
