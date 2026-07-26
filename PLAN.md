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
| 상태 관리 | Riverpod |
| 로컬 저장소 | SQLite (sqflate) |
| 프로젝트 구조 | Feature + Layer 혼합 |
| 테스트 | 단위 + 위젯 + 통합 |

---

## UI/UX 디자인

### 테마
- **primary**: `#4CAF50` (그린)
- **primaryLight**: `#81C784`
- **primaryDark**: `#388E3C`
- **accent**: `#FFC107` (앰버)
- **background**: `#FFFFFF` (라이트) / `#121212` (다크)
- **surface**: `#FFFFFF` (라이트) / `#1E1E1E` (다크)

### 네비게이션
바텀 네비게이션 5탭:
1. 📚 단어장 (Word List)
2. 🔄 복습 (Review)
3. ❓ 퀴즈 (Quiz)
4. 🧩 매칭 (Matching)
5. ⚙️ 설정 (Settings)

### 아이콘
- **앱 아이콘**: 나무 + 말풍선 컨셉
- **플랫폼 아이콘**: 각 플랫폼별 디자인 가이드 따름

---

## 데이터 모델

### Word
```dart
class Word {
  final String id;
  final String english;
  final String korean;
  final String? exampleSentence;
  final String? pronunciation;
  final List<String> tags;
  final int difficulty; // 1-5
  final String? memo;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

### ReviewCard
```dart
class ReviewCard {
  final String id;
  final String wordId;
  final String reviewMethod; // 'linear' | 'fixed'
  final int fixedIntervalDays; // 고정 간격일 때만
  final DateTime nextReviewDate;
  final int reviewCount;
  final DateTime createdAt;
}
```

### ReviewLog
```dart
class ReviewLog {
  final String id;
  final String wordId;
  final DateTime reviewedAt;
  final bool isCorrect;
}
```

### Settings
```dart
class AppSettings {
  final bool isDarkMode;
  final String reviewMethod; // 'linear' | 'fixed'
  final int fixedIntervalDays;
  final bool notificationEnabled;
  final TimeOfDay notificationTime;
}
```

---

## 기능 상세

### 1. 단어 등록 (Word List)
- 단어, 뜻, 예문, 발음, 태그, 난이도, 메모 입력
- 태그로 주제별 분류 (비즈니스, 여행, 일상 등)
- 난이도 레벨 1-5
- 검색 기능 (단어, 뜻, 태그로 검색)

### 2. 복습 시스템 (Review)
- **방식 선택**: 레이니어 또는 고정 간격
- **레이니어**: 1일 → 3일 → 7일 → 30일
- **고정 간격**: 매일/2일/3일/7일/14일/30일 중 선택
- **복습 로그**: 복습 일시, 정답 여부 기록

### 3. 플래시카드 (Flashcard)
- **기본형**: 카드 탭으로 뒤집기, 스와이프로 '알았다/몰랐다'
- **입력형**: 뜻을 직접 타이핑 후 정답 확인
- **모드 전환**: 기본형 ↔ 입력형 전환 버튼

### 4. 퀴즈 (Quiz)
- **영어→뜻 객관식**: 영어 단어를 보고 올바른 한국어 뜻 선택 (4지 선다)
- **빈칸 채우기**: 예문의 빈칸에 단어 입력
- **점수 기록**: 정답률, 소요 시간 표시

### 5. 매칭 (Matching)
- **단어-뜻 매칭**: 메모리 카드 게임 스타일. 카드를 뒤집어 단어-뜻 짝짓기
- **그리드 매칭**: 4x4 그리드에 단어/뜻을 배치하고 같은 것끼리 연결
- **자유 모드**: 시간/횟수 제한 없이 완료만 하면 됨

### 6. 뜻 타이핑
- 영어 단어를 보고 한국어 뜻을 직접 타이핑
- 부분 일치도 허용 (예: "사과" → "사과, Apple")

### 7. 철자 타이핑
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
- **다크 모드**: 시스템 설정 따르기 / 수동 선택
- **복습 방식**: 레이니어 / 고정 간격 선택
- **고정 간격**: 매일/2일/3일/7일/14일/30일 중 선택
- **알림 시간**: 복습 알림 시간 설정

---

## 프로젝트 구조

```
lib/
├── main.dart
├── app.dart
├── core/
│   ├── constants/
│   ├── theme/
│   │   ├── app_theme.dart
│   │   └── app_colors.dart
│   ├── utils/
│   └── extensions/
├── features/
│   ├── words/
│   │   ├── data/
│   │   │   ├── models/
│   │   │   │   ├── word.dart
│   │   │   │   └── review_card.dart
│   │   │   └── repositories/
│   │   │       └── word_repository.dart
│   │   ├── presentation/
│   │   │   ├── providers/
│   │   │   ├── screens/
│   │   │   │   ├── word_list_screen.dart
│   │   │   │   └── word_form_screen.dart
│   │   │   └── widgets/
│   │   └── word_feature.dart
│   ├── review/
│   │   ├── data/
│   │   │   ├── models/
│   │   │   └── repositories/
│   │   ├── presentation/
│   │   │   ├── providers/
│   │   │   ├── screens/
│   │   │   │   ├── review_screen.dart
│   │   │   │   └── flashcard_screen.dart
│   │   │   └── widgets/
│   │   └── review_feature.dart
│   ├── quiz/
│   │   ├── data/
│   │   ├── presentation/
│   │   │   ├── screens/
│   │   │   │   ├── quiz_screen.dart
│   │   │   │   ├── meaning_quiz_screen.dart
│   │   │   │   └── fill_blank_quiz_screen.dart
│   │   │   └── widgets/
│   │   └── quiz_feature.dart
│   ├── matching/
│   │   ├── data/
│   │   ├── presentation/
│   │   │   ├── screens/
│   │   │   │   ├── matching_screen.dart
│   │   │   │   ├── word_matching_screen.dart
│   │   │   │   └── grid_matching_screen.dart
│   │   │   └── widgets/
│   │   └── matching_feature.dart
│   └── settings/
│       ├── data/
│       ├── presentation/
│       │   ├── screens/
│       │   │   └── settings_screen.dart
│       │   └── widgets/
│       └── settings_feature.dart
├── shared/
│   ├── widgets/
│   │   ├── app_bottom_navigation.dart
│   │   └── common_widgets.dart
│   └── services/
│       ├── database_service.dart
│       ├── backup_service.dart
│       └── notification_service.dart
└── home/
    ├── home_screen.dart
    └── widgets/
```

---

## 구현 단계

### Phase 1: 프로젝트 셋업 & 기본 구조
1. Flutter 프로젝트 생성
2. 의존성 추가 (riverpod, sqflite, path_provider 등)
3. 테마 시스템 구현 (라이트/다크)
4. 바텀 네비게이션 구현
5. SQLite 데이터베이스 초기화

### Phase 2: 단어 관리
1. Word 모델 구현
2. WordRepository 구현 (CRUD)
3. 단어 목록 화면 구현
4. 단어 등록/수정/삭제 화면 구현
5. 검색 기능 구현

### Phase 3: 복습 시스템
1. ReviewCard 모델 구현
2. ReviewRepository 구현
3. 복습 방식 설정 (레이니어/고정 간격)
4. 복습 화면 구현
5. 복습 로그 기록

### Phase 4: 플래시카드
1. 기본형 플래시카드 (스와이프/탭)
2. 입력형 플래시카드 (타이핑)
3. 모드 전환 기능

### Phase 5: 퀴즈
1. 영어→뜻 객관식 퀴즈
2. 빈칸 채우기 퀴즈
3. 점수 기록

### Phase 6: 매칭
1. 단어-뜻 매칭 (메모리 카드)
2. 그리드 매칭
3. 자유 모드

### Phase 7: 뜻/철자 타이핑
1. 뜻 타이핑 기능
2. 철자 타이핑 기능

### Phase 8: 추가 기능
1. JSON 내보내기/가져오기
2. 자동 백업
3. 로컬 알림
4. 홈 화면 위젯

### Phase 9: 테스트 & 다듬기
1. 단위 테스트 작성
2. 위젯 테스트 작성
3. 통합 테스트 작성
4. UI/UX 다듬기
5. 성능 최적화

---

## 의존성 패키지

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.4.0
  sqflite: ^2.3.0
  path_provider: ^2.1.0
  path: ^1.8.0
  uuid: ^4.2.0
  intl: ^0.19.0
  flutter_local_notifications: ^17.0.0
  home_widget: ^0.4.0
  share_plus: ^7.2.0
  file_picker: ^6.1.0
  flutter_slidable: ^3.0.0
  flutter_staggered_animations: ^1.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  mockito: ^5.4.0
  build_runner: ^2.4.0
  sqflite_common_ffi: ^2.3.0
```
