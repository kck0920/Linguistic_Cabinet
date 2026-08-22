# VocaTree — Agent Guide

## Communication

- **Always respond in Korean (한국어).** All explanations, comments, questions, and summaries must be in Korean.

## Quick start

```bash
export PATH="$HOME/flutter/bin:$PATH"
flutter pub get
flutter analyze                          # lint + typecheck
flutter build web --release              # web build (used for testing)
```

## Dev server (web)

```bash
cd build/web && python3 -m http.server 3001 --bind 0.0.0.0
```
Open `http://localhost:3001`. `flutter run -d web-server` tends to die — prefer static build.

## Key commands

| Command | Purpose |
|---------|---------|
| `flutter analyze` | Lint + typecheck |
| `flutter build web --release` | Build for web |
| `flutter test` | Run tests |

## DB platform quirks (CRITICAL)

SQLite requires platform-specific backends. Must init **before any DB call**.

- **Web** (`kIsWeb`): `databaseFactoryFfiWeb` from `sqflite_common_ffi_web`
- **Desktop** (Linux/Windows/macOS): `sqfliteFfiInit()` + `databaseFactoryFfi` from `sqflite_common_ffi`
- **Mobile** (Android/iOS): default `sqflite`

See `lib/main.dart:9-15` and `lib/shared/services/database_service.dart:17-33`. Always test on target platform.

## Google OAuth setup (desktop)

데스크톱(Linux/Windows) 구글 로그인은 gitignored 시크릿 파일이 필요하다.
파일이 없으면 **컴파일 자체가 실패**한다 (analyze/test/build 전부).

```bash
cp lib/shared/services/oauth_credentials.example.dart \
   lib/shared/services/oauth_credentials.dart   # clientId 채워 넣기
```

- `clientSecret`은 선택값 — 설치형 앱은 PKCE만으로 동작 (`desktop_google_auth_service.dart` 참고)
- 웹용 Client ID는 공개 값이라 커밋됨: `lib/shared/services/oauth_public_ids.dart`

## Project architecture

- **Entry**: `lib/main.dart` → `lib/app.dart` → `lib/home/home_screen.dart`
- **State**: Riverpod (`flutter_riverpod`), providers defined in screen files (e.g. `word_list_screen.dart:8-25`)
- **Storage**: SQLite via `DatabaseService` singleton (tables: `words`, `review_cards`, `review_logs`, `settings`)
- **Features** in `lib/features/<name>/`:
  - `words/` — models, repos, screens (list + form), widgets (card)
  - `review/` — models, repos, screens (review home + flashcard)
  - `quiz/` — screens (quiz type, meaning quiz, fill blank, meaning/spelling typing)
  - `matching/` — screens (matching type, word matching, grid matching)
  - `achievements/` — 업적 평가/서비스 + 컬렉션·인증서 화면
  - `settings/` — screens (dark mode, review method, export/import, delete all) + data services (backup, home widget, review reminder)
- **Google Drive sync**: `lib/shared/services/google_*.dart` (auth/drive/sync/session/token-refresh)
- **Shared widgets**: `lib/shared/widgets/cabinet_*.dart` (garden, streak, badges, surfaces 등)
- **File picker/saver**: conditional exports in `lib/core/utils/` — platform-specific impls per file triplet
- **Riverpod providers**: screen-local (same file as screen), not in dedicated `providers/` dirs

## Tests

23개 테스트 파일, 약 140+ 테스트 — 전부 통과해야 함.

- 단위 + 위젯 테스트 혼재. DB는 `DatabaseService.setTestDatabaseInMemory()`로 인메모리 대체 (`test/helpers.dart` 참고)
- `flutter test` 한 번에 전부 실행. 개별 파일: `flutter test test/model_test.dart`

## Gotchas

- `file_picker` prints warnings for linux/macos/windows default plugins — harmless
- Web build shows `dart:html` unsupported warnings for `file_picker`/`share_plus` — they work at runtime
- Riverpod providers are screen-local (defined in same file as screen)
- DB factory **must be initialized before any DB call** (see `main.dart`)
- DB 마이그레이션은 `_onUpgrade` 하나에서만 관리 (`database_service.dart`) — 웹/네이티브 분기 각각 수정 금지
- 거대 파일 주의: 설정/대시보드/정원은 셸 + 위젯 분할 구조다 — `settings/presentation/widgets/settings_*_tab.dart`, `home/widgets/dashboard_*.dart`, `shared/widgets/cabinet_plant_painter.dart` 참고

## Agent skills

### Issue tracker

이슈는 `.scratch/` 디렉토리의 로컬 마크다운 파일로 관리됩니다. See `docs/agents/issue-tracker.md`.

### Triage labels

기본 5개 트라이아지 역할 라벨 사용. See `docs/agents/triage-labels.md`.

### Domain docs

단일 컨텍스트 (repo root에 CONTEXT.md + docs/adr/). See `docs/agents/domain.md`.