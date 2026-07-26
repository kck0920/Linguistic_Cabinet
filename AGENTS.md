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

## Project architecture

- **Entry**: `lib/main.dart` → `lib/app.dart` → `lib/home/home_screen.dart`
- **State**: Riverpod (`flutter_riverpod`), providers defined in screen files (e.g. `word_list_screen.dart:8-25`)
- **Storage**: SQLite via `DatabaseService` singleton (tables: `words`, `review_cards`, `review_logs`, `settings`)
- **Features** in `lib/features/<name>/`:
  - `words/` — models, repos, screens (list + form), widgets (card)
  - `review/` — models, repos, screens (review home + flashcard)
  - `quiz/` — screens (quiz type, meaning quiz, fill blank)
  - `matching/` — screens (matching type, word matching, grid matching)
  - `settings/` — screens (dark mode, review method, export/import, delete all)
- **File picker/saver**: conditional exports in `lib/core/utils/` — platform-specific impls per file triplet
- **Riverpod providers**: screen-local (same file as screen), not in dedicated `providers/` dirs

## Remaining work (from PLAN.md)

- Meaning typing (Phase 7)
- Spelling typing (Phase 7)
- Auto backup (Phase 8)
- Local notifications (Phase 8)
- Home widget (Phase 8)
- Proper tests (Phase 9 — current `test/widget_test.dart` is a stub)

## Test current state

`test/widget_test.dart` only calls `runApp()` — no assertions. Needs `ProviderScope` + DB mock (`sqflite_common_ffi` for tests).

## Gotchas

- `file_picker` prints warnings for linux/macos/windows default plugins — harmless
- Web build shows `dart:html` unsupported warnings for `file_picker`/`share_plus` — they work at runtime
- `PLAN.md` documents full architecture but some paths in tree diagram don't exist (no feature barrels, no `shared/widgets/`)
- Riverpod providers are screen-local (defined in same file as screen)
- DB factory **must be initialized before any DB call** (see `main.dart:9-15`)

## Agent skills

### Issue tracker

이슈는 `.scratch/` 디렉토리의 로컬 마크다운 파일로 관리됩니다. See `docs/agents/issue-tracker.md`.

### Triage labels

기본 5개 트라이아지 역할 라벨 사용. See `docs/agents/triage-labels.md`.

### Domain docs

단일 컨텍스트 (repo root에 CONTEXT.md + docs/adr/). See `docs/agents/domain.md`.