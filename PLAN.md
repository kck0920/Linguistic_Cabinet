# VocaTree — 구현 계획

## 프로젝트 개요

**앱 이름**: VocaTree  
**목적**: 모든 플랫폼에서 사용 가능한 영어 단어장  
**기술 스택**: Flutter (Dart)  
**타겟 플랫폼**: iOS, Android, Web, Windows, macOS, Linux

---

## 기술 결정

| 항목 | 선택 |
|------|------|
| 프레임워크 | Flutter |
| 상태 관리 | Riverpod (프로바이더는 화면 파일 로컬 정의) |
| 로컬 저장소 | SQLite (sqflite + common_ffi/web) |
| 프로젝트 구조 | Feature + Layer 혼합 (data/models·repositories / presentation/screens) |
| 테스트 | 단위 + 위젯 + 통합 (141 + 1개, 통합은 Linux 데스크톱) |

---

## UI/UX 디자인

### 테마 (캐비닛 Neo-Brutal)
- **5개 모드**: `sepia`(기본)·`forest`·`lavender`·`sunset`·`mono` (설정에서 전환)
- **컬러 시스템**: `paper`(배경 3단)·`ink`(텍스트 4단 + 라인 2단)·`accent`(스탬프 레드 3단 + 블루)·`tape`(마스킹 테이프 4색)·`brutal`(네오브루탈 배경/잉크/섀도)
- **대표색**: sepia 기본 `accent #B8562D`(버건디) + `accent2 #C88A2A`(머스터드) + `accent3 #4A6B3A`(올리브)
- **폰트**: 구글 폰트 + 카탈로그/핸드노트/세리프 스타일 (`cabinet_theme.dart`)

### 네비게이션
**6탭** (모바일: 하단 바, 데스크톱: 상단 네비 — 화면폭 720px 기준 전환):
1. 🏠 홈 (Home) — 대시보드·LEDGER SUMMARY·스트릭 잔디
2. 📚 컬렉션 (Collection) — 단어장
3. 🔄 복습 (Review) — 오늘의 복습
4. ❓ 퀴즈 (Quiz)
5. 🧩 매칭 (Match)
6. ⚙️ 설정 (Settings)

### 아이콘
- **앱 아이콘**: 나무 + 말풍선 컨셉
- **플랫폼 아이콘**: 각 플랫폼별 디자인 가이드 따름

---

## 데이터 모델

### Word (`lib/features/words/data/models/word.dart`)
```dart
class Word {
  final String id;
  final String english;
  final String korean;
  final String? exampleSentence;
  final String? pronunciation;
  final List<String> tags;
  final int difficulty; // 1-5 (복습 결과로 자동 조정: 정답 -1 / 오답 +1)
  final String? memo;
  final String? imagePath;    // WebP 이미지 (파일 경로 또는 base64)
  final String? dictionaryUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

### ReviewCard (`lib/features/review/data/models/review_card.dart`)
```dart
enum ReviewMethod { linear, fixed, sm2 }

class ReviewCard {
  final String id;
  final String wordId;
  final ReviewMethod reviewMethod;
  final ReviewMethod? overrideMethod; // 단어별 방식 오버라이드 (activeMethod 우선)
  final int? fixedIntervalDays;       // fixed 방식일 때
  final DateTime nextReviewDate;
  final int reviewCount;
  final DateTime createdAt;

  // SM-2 알고리즘 필드
  final double easinessFactor; // 1.3 ~ 5.0
  final int interval;          // 다음 복습까지 일수
  final int repetition;        // 연속 정답 횟수
}
```
- **방식**: linear(1→3→7→30일) / fixed(고정 간격) / **sm2(간격 반복 — 기본)**
- **단어별 오버라이드**: `override_method` 컬럼으로 전역 설정과 무관하게 개별 단어 방식 지정 (ADR 0002)
- **숙달 기준**: 난이도 ≤ 2 (복습 결과가 자동 반영, ADR 0004)

### StudyLog (`lib/features/review/data/models/study_log.dart`) — review_logs 테이블
```dart
class StudyLog {
  final String id;
  final String wordId;
  final DateTime reviewedAt;
  final bool isCorrect;
  final String? studyMethod; // 'flashcard' | 'meaning_quiz' | 'fill_blank' |
                             // 'meaning_typing' | 'spelling_typing' |
                             // 'word_matching' | 'grid_matching'
  final int? durationMs;
  final String? answerType;  // 'swipe' | 'tap' | 'typing'
}
```

### Settings (settings 테이블 — key/value 2열)
- 설정은 클래스 대신 `settings(key PRIMARY KEY, value TEXT)` 키-값 테이블로 저장
- 주요 키: `dark_mode`(→ 캐비닛 모드), `review_method`, `fixed_interval_days`,
  `auto_difficulty`(난이도 자동 반영 토글), `reminder_enabled`·`reminder_time`,
  `auto_backup`, `master_garden_badge`·`anniversary_seen`(업적/기념일)

---

## 기능 상세

### 1. 단어 등록 (Word List)
- 단어, 뜻, 예문, 발음, 태그, 난이도(별 1-5), 메모 입력
- **WebP 이미지 첨부** (파일 선택 또는 base64 저장)
- **네이버 사전 연동 URL** 자동 생성 (사전 링크)
- **마크다운 메모** (입력/뷰 전환 프리뷰)
- 태그로 주제별 분류 (비즈니스, 여행, 일상 등)
- 검색 기능 (단어, 뜻, 태그로 검색)

### 2. 복습 시스템 (Review)
- **방식 선택**: SM-2(간격 반복)·레이니어(1→3→7→30일)·고정 간격 중 선택
- **SM-2**: easiness factor·interval·repetition 기반 간격 반복 (기본 방식)
- **단어별 오버라이드**: 개별 단어마다 복습 방식 지정 가능 (ADR 0002)
- **복습 결과 → 난이도 자동 반영**: 정답 -1 / 오답 +1 (1~5 범위, 설정에서 토글 가능, ADR 0004)
- **복습 로그**: 학습 일시·정답 여부·학습 방법(플래시카드/퀴즈/매칭 등)·소요 시간·답변 유형 기록

### 3. 플래시카드 (Flashcard)
- **기본형**: 카드 탭으로 뒤집기, 스와이프(→ Known / ← Again)로 답변
- 완료 시 복습 로그·SM-2 일정 반영·업적 즉시 평가
- (입력형 타이핑은 퀴즈 탭의 뜻/철자 타이핑 EXAM으로 분리 구현)

### 4. 퀴즈 (Quiz) — 4개 EXAM 모드
- **뜻 맞추기**: 영어 단어를 보고 4지선다로 뜻 선택 (정답/오답 하이라이트)
- **빈칸 채우기**: 예문의 빈칸에 알맞은 단어 선택
- **뜻 타이핑**: 단어를 보고 한국어 뜻 주관식 입력
- **철자 타이핑**: 뜻을 보고 영어 철자 주관식 입력
- **점수 기록**: 10문제 기준 정답률 % + 결과 다이얼로그(정답/다시 하기)
- 답변마다 `logReview` + `processReviewResult`(SM-2) + 업적 즉시 평가

### 5. 매칭 (Matching) — 2개 게임 모드
- **단어-뜻 잇기 (Line Match)**: 좌측 단어·우측 뜻을 클릭해 페어 매칭
- **그리드 메모리 (Grid Memory)**: 4x3 그리드(12카드)를 뒤집어 단어-뜻 짝 맞추기
- **최소 4단어 필요** (미달 시 안내)
- 모든 쌍 완료 시 각 단어 `logReview`(word_matching/grid_matching) + `processReviewResult` + 업적 즉시 평가

### 6. 뜻 타이핑 (퀴즈 EXAM 03)
- 영어 단어를 보고 한국어 뜻을 직접 타이핑
- 부분 일치도 허용 (예: "사과" → "사과, Apple")

### 7. 철자 타이핑 (퀴즈 EXAM 04)
- 한국어 뜻을 보고 영어 단어를 직접 타이핑
- 오타 허용 범위 설정 가능

---

## 추가 기능

### 데이터 관리
- **JSON 내보내기**: 단어장을 JSON 파일로 저장
- **JSON 가져오기**: JSON 파일에서 단어장 복원
- **자동 백업**: 앱 시작 시 자동으로 백업 파일 생성

### 알림 & 위젯
- **로컬 알림**: 지정한 시간에 복습 알림 푸시
- **홈 화면 위젯**: 오늘의 복습 단어 수 표시

### 설정
- **캐비닛 테마 모드**: sepia / forest / lavender / sunset / mono 중 선택
- **복습 방식**: SM-2 / 레이니어 / 고정 간격 선택 (+ 단어별 오버라이드)
- **고정 간격**: 매일/2일/3일/7일/14일/30일 중 선택
- **난이도 자동 반영**: 복습 결과를 단어 난이도에 반영할지 토글
- **알림 시간**: 복습 알림 시간 설정

---

## 프로젝트 구조 (실제 `lib/` 기준)

```
lib/
├── main.dart                    # 진입점 (DB 플랫폼 초기화 → runApp)
├── app.dart                     # VocaTreeApp (테마·다크모드·primary color 프로바이더)
├── core/
│   ├── theme/
│   │   ├── app_theme.dart       # (레거시 테마)
│   │   ├── app_colors.dart      # (레거시 테마)
│   │   ├── cabinet_theme.dart   # 캐비닛 테마 (폰트·마크다운 스타일)
│   │   └── cabinet_colors.dart  # 캐비닛 팔레트 (sepia/mono/… 모드별)
│   └── utils/                   # 조건부 export (io/stub/web 3종 파일 패턴)
│       ├── file_picker_helper.dart (+ _io/_stub/_web)
│       ├── file_saver.dart (+ _io/_stub/_web)
│       ├── platform_helper.dart (+ _io/_stub/_web)
│       ├── url_launcher_helper.dart (+ _io/_stub/_web)
│       ├── home_widget_helper.dart (+ _io/_stub)
│       └── format_count.dart
├── features/
│   ├── words/
│   │   ├── data/models/word.dart
│   │   ├── data/repositories/word_repository.dart
│   │   └── presentation/screens/word_list_screen.dart, word_form_screen.dart
│   │       presentation/widgets/word_card.dart
│   ├── review/
│   │   ├── data/models/review_card.dart, study_log.dart
│   │   ├── data/repositories/review_repository.dart  # SM-2·getMasteredCount·통계
│   │   └── presentation/screens/review_screen.dart, flashcard_screen.dart
│   ├── quiz/
│   │   └── presentation/screens/quiz_screen.dart, meaning_quiz_screen.dart,
│   │       fill_blank_quiz_screen.dart, meaning_typing_screen.dart, spelling_typing_screen.dart
│   ├── matching/
│   │   └── presentation/screens/matching_screen.dart, word_matching_screen.dart,
│   │       grid_matching_screen.dart
│   ├── settings/
│   │   ├── data/services/review_reminder_service.dart, backup_service.dart,
│   │   │   home_widget_service.dart
│   │   └── presentation/screens/settings_screen.dart, stats_screen.dart
│   └── achievements/
│       ├── data/models/achievement.dart
│       ├── data/achievement_service.dart, anniversary_service.dart,
│       │   achievement_evaluator.dart
│       └── presentation/achievement_collection_screen.dart,
│           achievement_detail_screen.dart, achievement_toast_overlay.dart,
│           master_garden_certificate_screen.dart, master_garden_guide_screen.dart
├── home/
│   ├── home_screen.dart         # 탭 네비게이션 (홈/컬렉션/복습/퀴즈/매칭/설정)
│   └── home_dashboard_screen.dart  # 대시보드·LEDGER SUMMARY·스트릭 잔디
├── shared/
│   ├── services/database_service.dart  # SQLite 싱글턴 (스키마·마이그레이션)
│   └── widgets/cabinet_widgets.dart     # 캐비닛 공용 위젯 (버튼·카드·스탬프 등)
└── dev/
    ├── garden_preview_screen.dart   # 정원 미리보기 (개발용)
    └── main_garden_preview.dart     # 정원 미리보기 진입점 (개발용)
```

> 참고: 프로바이더는 별도 `providers/` 디렉토리 없이 **화면 파일과 같은 파일에 정의**된다.
> feature barrel(`word_feature.dart` 등)은 사용하지 않는다.

---

## 구현 단계

### Phase 1: 프로젝트 셋업 & 기본 구조 ✅
1. Flutter 프로젝트 생성 ✅
2. 의존성 추가 (riverpod, sqflite, path_provider 등) ✅
3. 테마 시스템 구현 (캐비닛 5모드) ✅
4. 탭 네비게이션 구현 (모바일 하단바/데스크톱 상단바) ✅
5. SQLite 데이터베이스 초기화 ✅

### Phase 2: 단어 관리 ✅
1. Word 모델 구현 ✅
2. WordRepository 구현 (CRUD) ✅
3. 단어 목록 화면 구현 ✅
4. 단어 등록/수정/삭제 화면 구현 (WebP 이미지·사전 URL·마크다운 메모) ✅
5. 검색 기능 구현 ✅

### Phase 3: 복습 시스템 ✅
1. ReviewCard 모델 구현 (SM-2 필드 포함) ✅
2. ReviewRepository 구현 ✅
3. 복습 방식 설정 (SM-2/레이니어/고정 + 단어별 오버라이드) ✅
4. 복습 화면 구현 ✅
5. 복습 로그 기록 (StudyLog: 방법·소요시간·답변유형) ✅

### Phase 4: 플래시카드 ✅
1. 기본형 플래시카드 (플립 탭/스와이프) ✅
2. (입력형은 퀴즈 뜻/철자 타이핑 EXAM으로 구현) ✅

### Phase 5: 퀴즈 ✅
1. 뜻 맞추기 객관식 (4지선다) ✅
2. 빈칸 채우기 ✅
3. 뜻/철자 타이핑 (EXAM 03·04) ✅
4. 점수 기록 (정답률·결과 다이얼로그) ✅

### Phase 6: 매칭 ✅
1. 단어-뜻 잇기 (Line Match) ✅
2. 그리드 메모리 (4x3, 12카드) ✅

### Phase 7: 뜻/철자 타이핑 ✅ (구현 완료)
1. 뜻 타이핑 기능 ✅ (`meaning_typing_screen.dart`)
2. 철자 타이핑 기능 ✅ (`spelling_typing_screen.dart`)

### Phase 8: 추가 기능 ✅ (구현 완료)
1. JSON 내보내기/가져오기 ✅
2. 자동 백업 ✅ (설정 토글 + 앱 시작/백그라운드 시 ZIP 저장)
3. 로컬 알림 ✅ (지정 시간 zonedSchedule 예약 + 앱 시작 폴백)
4. 홈 화면 위젯 ✅ (Android — 복습 대상 수·숙달 수, `home_widget`)

### Phase 9: 테스트 & 다듬기 ✅ (전 항목 완료)
1. 단위 테스트 작성 ✅
2. 위젯 테스트 작성 ✅ (총 141개 — LEDGER·퀴즈/매칭 logReview·난이도 반영·업적·리마인더·홈 위젯)
3. 통합 테스트 작성 ✅ (`integration_test/review_home_stats_flow_test.dart` — 실제 앱 + 인메모리 DB로 복습→홈 복귀 통계 갱신 검증, Linux 데스크톱 실행)
4. UI/UX 다듬기 ✅
5. 성능 최적화 ✅ (업적 수여 개별 쿼리 ~52회 → `getSettings` 배치 조회 1회)

---

## 의존성 패키지

> 실제 `pubspec.yaml` 기준 (2026-08 기준)

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  google_fonts: ^6.1.0

  # State Management
  flutter_riverpod: ^2.4.0

  # Local Database
  sqflite: ^2.3.0
  sqflite_common_ffi: ^2.3.0
  sqflite_common_ffi_web: ^1.1.2
  path_provider: ^2.1.0
  path: ^1.8.0

  # Utilities
  uuid: ^4.2.0

  # File Operations
  share_plus: ^10.0.0
  file_picker: ^10.3.10  # AGP 9에서 11.x는 Kotlin 미컴파일, 8.3.7은 compileSdk 34 하드코딩 → 고정
  image: ^4.0.0
  archive: ^3.3.7

  # Markdown rendering
  flutter_markdown: ^0.7.0

  # Web
  web: ^1.1.0
  flutter_local_notifications: ^22.1.0
  timezone: ^0.11.1  # zonedSchedule용
  home_widget: ^0.9.3  # 홈 화면 위젯 (Android/iOS/macOS 전용)

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  mockito: ^5.4.0
  build_runner: ^2.4.0
```
