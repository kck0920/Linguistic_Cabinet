# VocaTree (Linguistic Cabinet)

[한국어](#korean) | [English](#english) · **Live Web**: <https://linguistic-cabinet.vercel.app>

<a id="korean"></a>
## 한국어 안내

### 소개
VocaTree(프로젝트명: Linguistic Cabinet)는 영어 단어를 기록하고, 간격 반복 복습(SRS), 퀴즈/매칭 게임, 업적·정원 요소를 통해 학습을 돕는 **크로스 플랫폼 Flutter 앱**입니다. 데이터는 로컬(SQLite)에 저장되며, 선택적으로 **Google Drive 동기화**를 사용할 수 있습니다.

### 주요 기능
- **단어장 (Words)**
  - 단어, 의미, 메모, 예문 등을 관리하는 단어 목록/등록·수정 화면 제공 (`word_list_screen.dart`, `word_form_screen.dart`)
- **간격 반복 복습 (Spaced Repetition)**
  - 복습 카드/복습 기록 기반 학습 흐름 제공 (`review_screen.dart`, `flashcard_screen.dart`)
  - 복습 방식 설정 및 알림/리마인더 관련 기능(설정 탭 및 서비스에서 제공)
- **퀴즈 (Quiz)**
  - 퀴즈 유형 선택 후 의미 퀴즈, 빈칸 채우기, 의미/철자 타이핑 등 다양한 연습 모드 제공
  - 관련 화면: `quiz_screen.dart`, `meaning_quiz_screen.dart`, `fill_blank_quiz_screen.dart`, `meaning_typing_screen.dart`, `spelling_typing_screen.dart`
- **매칭 (Matching)**
  - 단어 매칭/그리드 매칭 등 게임형 학습 제공
  - 관련 화면: `matching_screen.dart`, `word_matching_screen.dart`, `grid_matching_screen.dart`
- **업적 / 정원 (Achievements & Garden)**
  - 학습 진행에 따른 업적/컬렉션, 인증서/가이드 등 화면 제공
  - 관련: `achievement_collection_screen.dart`, `achievement_detail_screen.dart`, `master_garden_certificate_screen.dart`, `master_garden_guide_screen.dart`
- **TTS 발음**
  - 여성/남성 성별 분리 발음 재생 지원 (`tts_service.dart`, 웹 Web Speech API / 네이티브 `flutter_tts` 플랫폼별 엔진)
  - 미국식(`en-US`) 자연스러운 음성 우선 선택 및 여러 줄/문장 예문의 한 문장씩 개별 재생(`CabinetExampleSentences`) 지원
- **Google Drive 동기화**
  - Google 로그인/토큰 관리 및 Drive 동기화 서비스 제공 (`google_auth_service.dart`, `google_drive_service.dart`, `google_drive_sync_service.dart` 등)
  - 앱 시작 시 silent sign-in 및 리다이렉트 재인증 토큰 처리 로직 포함

### 기술 스택
- **프레임워크**: Flutter (Dart SDK `^3.12.2`)
- **상태 관리**: Riverpod (`flutter_riverpod`)
- **로컬 DB**: SQLite (`sqflite`, 데스크톱 `sqflite_common_ffi`, 웹 `sqflite_common_ffi_web`)
- **주요 패키지(발췌)**: `google_fonts`, `google_sign_in`, `googleapis`, `flutter_tts`, `flutter_local_notifications`, `home_widget`, `file_picker`, `share_plus`, `archive`, `flutter_markdown` 등
- **플랫폼**: Android / iOS / Web / macOS / Windows / Linux (Flutter 멀티플랫폼)

### 실행 및 테스트 방법
#### 사전 준비
- Flutter 설치 후 환경 변수 설정 (예: `export PATH="$HOME/flutter/bin:$PATH"`)
- 의존성 설치:

```bash
flutter pub get
```

#### 정적 분석 / 빌드 / 테스트
```bash
flutter analyze
flutter build web --release
flutter test
```

#### 웹 개발 서버 (권장)
`flutter run -d web-server`가 불안정할 수 있어, 빌드 후 정적 서버를 권장합니다.

```bash
flutter build web --release
cd build/web && python3 -m http.server 3001 --bind 0.0.0.0
```
브라우저에서 `http://localhost:3001` 접속.

#### 데스크톱 Google OAuth 설정
데스크톱(Linux/Windows) 구글 로그인은 gitignored 시크릿 파일이 필요하며, 파일이 없으면 컴파일/분석/빌드가 실패합니다.

```bash
cp lib/shared/services/oauth_credentials.example.dart \
   lib/shared/services/oauth_credentials.dart
```

- `clientSecret`은 선택값입니다(설치형 앱은 PKCE만으로 동작).
- 웹용 Client ID는 공개 값으로 `lib/shared/services/oauth_public_ids.dart`에 커밋되어 있습니다.

#### DB 플랫폼 초기화 (중요)
앱은 플랫폼별 SQLite 백엔드를 초기화한 뒤 DB를 사용합니다.
- **Web**: `databaseFactoryFfiWeb`
- **Desktop**: `sqfliteFfiInit()` + `databaseFactoryFfi`
- **Mobile**: 기본 `sqflite`

진입점/서비스 초기화 로직은 `lib/main.dart`, `lib/shared/services/database_service.dart`를 참고하세요.

### 프로젝트 구조 (요약)
```text
lib/
├─ main.dart                  # 앱 진입점, 플랫폼별 DB 초기화 및 시작 시 동기화/토큰 처리
├─ app.dart                   # MaterialApp 구성, 테마/프로바이더 연결
├─ home/                      # 홈 대시보드/탭 화면
├─ core/                      # 테마, 유틸, 공통 로직
├─ features/
│  ├─ words/                  # 단어장 (목록/폼)
│  ├─ review/                 # 간격 반복 복습
│  ├─ quiz/                   # 퀴즈 모드
│  ├─ matching/               # 매칭 게임
│  ├─ achievements/           # 업적/정원/인증서
│  └─ settings/               # 설정, 백업/동기화 관련 UI 및 서비스
└─ shared/
   ├─ services/               # DB, TTS, Google Drive/Auth, 세션 저장 등 공통 서비스
   └─ widgets/                # 공통 위젯
```

### 참고 문서
- `AGENTS.md`: 개발/에이전트 작업 가이드
- `docs/`: 추가 문서
- `test/`: 테스트 코드

---

<a id="english"></a>
## English Guide

### Overview
VocaTree (project name: Linguistic Cabinet) is a **cross-platform Flutter app** for managing English vocabulary and practicing with spaced repetition, quizzes, matching games, achievements, and garden-style progress elements. Data is stored locally (SQLite), with optional **Google Drive sync**.

### Key Features
- **Wordbook (Words)**
  - Manage vocabulary with list/form screens (`word_list_screen.dart`, `word_form_screen.dart`)
- **Spaced Repetition Review**
  - Review flow built around review cards/logs (`review_screen.dart`, `flashcard_screen.dart`)
- **Quizzes**
  - Multiple practice modes such as meaning quiz, fill-in-the-blank, meaning typing, and spelling typing
  - Screens: `quiz_screen.dart`, `meaning_quiz_screen.dart`, `fill_blank_quiz_screen.dart`, `meaning_typing_screen.dart`, `spelling_typing_screen.dart`
- **Matching Games**
  - Word/grid matching activities
  - Screens: `matching_screen.dart`, `word_matching_screen.dart`, `grid_matching_screen.dart`
- **Achievements & Garden**
  - Achievement/collection screens and certificate/guide views
  - Examples: `achievement_collection_screen.dart`, `achievement_detail_screen.dart`, `master_garden_certificate_screen.dart`, `master_garden_guide_screen.dart`
- **TTS Pronunciation**
  - Female/male voice separation (`tts_service.dart`, Web Speech API on web / `flutter_tts` on native)
  - Prioritizes natural `en-US` voices and supports per-sentence playback for multi-sentence examples (`CabinetExampleSentences`)
- **Google Drive Sync**
  - Google auth/token handling and Drive sync services (`google_auth_service.dart`, `google_drive_service.dart`, `google_drive_sync_service.dart`, etc.)
  - Includes startup silent sign-in and redirect re-auth token handling

### Tech Stack
- **Framework**: Flutter (Dart SDK `^3.12.2`)
- **State management**: Riverpod (`flutter_riverpod`)
- **Local DB**: SQLite (`sqflite`, `sqflite_common_ffi` on desktop, `sqflite_common_ffi_web` on web)
- **Notable packages (excerpt)**: `google_fonts`, `google_sign_in`, `googleapis`, `flutter_tts`, `flutter_local_notifications`, `home_widget`, `file_picker`, `share_plus`, `archive`, `flutter_markdown`
- **Platforms**: Android, iOS, Web, macOS, Windows, Linux

### Getting Started
#### Prerequisites
- Install Flutter and set up your PATH (example): `export PATH="$HOME/flutter/bin:$PATH"`
- Install dependencies:

```bash
flutter pub get
```

#### Analyze / Build / Test
```bash
flutter analyze
flutter build web --release
flutter test
```

#### Web dev server (recommended)
`flutter run -d web-server` can be unstable; a static server is recommended:

```bash
flutter build web --release
cd build/web && python3 -m http.server 3001 --bind 0.0.0.0
```
Open `http://localhost:3001`.

#### Desktop Google OAuth setup
Desktop (Linux/Windows) Google sign-in requires a gitignored credentials file; without it, analysis and builds will fail:

```bash
cp lib/shared/services/oauth_credentials.example.dart \
   lib/shared/services/oauth_credentials.dart
```

- `clientSecret` is optional (installed apps work with PKCE).
- The web client ID is a public value committed at `lib/shared/services/oauth_public_ids.dart`.

#### DB initialization (important)
The app initializes a platform-specific SQLite backend before DB usage:
- **Web**: `databaseFactoryFfiWeb`
- **Desktop**: `sqfliteFfiInit()` + `databaseFactoryFfi`
- **Mobile**: default `sqflite`

See `lib/main.dart` and `lib/shared/services/database_service.dart`.

### Project Structure (summary)
```text
lib/
├─ main.dart                  # App entry, platform DB init, startup sync/token handling
├─ app.dart                   # MaterialApp setup, theme/providers
├─ home/                      # Home dashboard/tabs
├─ core/                      # Theme, utils, shared logic
├─ features/
│  ├─ words/                  # Wordbook (list/form)
│  ├─ review/                 # Spaced repetition review
│  ├─ quiz/                   # Quiz modes
│  ├─ matching/               # Matching games
│  ├─ achievements/           # Achievements/garden/certificates
│  └─ settings/               # Settings, backup/sync UI and services
└─ shared/
   ├─ services/               # DB, TTS, Google Drive/Auth, session storage
   └─ widgets/                # Shared widgets
```

### References
- `AGENTS.md`: development/agent workflow notes
- `docs/`: additional docs
- `test/`: test suite