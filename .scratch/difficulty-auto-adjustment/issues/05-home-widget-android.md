# 05 — 홈 화면 위젯 (Android)

Status: resolved

## 요구사항

PLAN.md Phase 8-4의 마지막 미구현 항목이던 홈 화면 위젯. "오늘의 복습 단어 수 표시"가 계획이었으나, 사용자 결정으로 범위를 좁혀 **Android 전용 + 복습 대상 수·숙달 단어 수** 2개 지표를 표시하는 위젯을 구현.

- Android App Widget 1종 (홈 화면에 배치, 대기 화면 없이 스냅샷 렌더링)
- 복습 대상 수(due) + 숙달 단어 수(mastered) 표시
- 학습 상태가 바뀔 때마다 위젯 데이터 최신화

## 결정 사항

- `home_widget ^0.9.3` 사용 (PLAN.md에 ^0.4.0 계획 — 최신 안정 버전으로 상향).
- **Android 전용** 구현 — iOS/macOS는 `iOSName`만 지정해 두어 추후 WidgetKit Extension 추가 시 Dart 쪽 수정 없이 Swift 구현만 추가하면 됨. 웹·Windows·Linux는 home_widget 미지원 → 조건부 export 헬퍼(`home_widget_helper_io/stub`)로 무시 (프로젝트 플랫폼 유틸 관례와 동일).
- **데이터 흐름**: 위젯이 SQLite를 직접 읽지 않고, 앱이 학습 상태를 `HomeWidget.saveWidgetData`로 SharedPreferences에 스냅샷 저장 → 네이티브 `HomeWidgetProvider`가 이를 읽어 렌더링.
- 갱신 지점 3곳: ① 앱 시작(홈 화면) ② 홈 탭 복귀(대시보드 탭 리스너 — 복습·퀴즈·매칭 직후 자동 최신화) ③ 설정 가져오기·전체 삭제 후(`_refreshAllProviders`).
- Android 빌드 사전 문제 3건 해결: `flutter_local_notifications` 22.x의 core library desugaring 요구, `file_picker 8.3.7`의 compileSdk 34 하드코딩(lifecycle 2.0.35가 36 요구로 충돌), `file_picker 11.x`의 AGP 9 Kotlin 미컴파일 문제.

## 구현

- `pubspec.yaml` — `home_widget ^0.9.3` 추가, `file_picker 10.3.10` 고정 (11.x는 AGP 9에서 Kotlin 플러그인 건너뜀)
- `android/app/src/main/kotlin/com/vocatree/vocatree/VocaTreeWidgetProvider.kt` — `HomeWidgetProvider` 상속, SharedPreferences의 `due_count`/`mastered_count`를 RemoteViews에 렌더링
- `android/app/src/main/res/layout/vocatree_widget.xml` — 복습/숙달 2칸 카드 (다크그린·앰버), `res/drawable/vocatree_widget_bg.xml` — 위젯 배경, `res/xml/vocatree_widget_info.xml` — 위젯 크기·설명
- `android/app/src/main/AndroidManifest.xml` — `VocaTreeWidgetProvider` receiver 등록 (`exported=true` + `home_widget_info` meta-data)
- `lib/core/utils/home_widget_helper_io.dart` / `home_widget_helper_stub.dart` — 조건부 export (io는 `dart:io Platform` 가드로 Android/iOS/macOS만 지원, Windows/Linux·테스트는 stub)
- `lib/features/settings/data/services/home_widget_service.dart` — `refreshWidgetData()`: due/mastered 스냅샷 저장 + `updateWidget` (내부 예외 격리)
- 갱신 지점 연결: `lib/home/home_screen.dart`(앱 시작 `_refreshHomeWidget`), `lib/home/home_dashboard_screen.dart`(홈 탭 복귀 리스너에서 `unawaited` 호출), `lib/features/settings/presentation/screens/settings_screen.dart`(`_refreshAllProviders`에 추가)
- `android/app/build.gradle.kts` — `compileSdk = 36` + `isCoreLibraryDesugaringEnabled` + `desugar_jdk_libs 2.1.4`

## 검증

- `flutter analyze` No issues
- `test/home_widget_service_test.dart` 신규 4개 — 스냅샷 저장·플랫폼 가드·예외 안전성 (플랫폼 헬퍼 Fake 주입)
- 전체 `flutter test` 139개 통과
- `flutter build apk --debug` 성공 — 위젯 Kotlin·XML·Manifest·플러그인 등록 검증 (이 프로젝트의 첫 APK 빌드 검증이기도 함)

## Comments

- (사용자) 범위 결정: "Android만 구현" + "복습 대상 수 + 숙달 수" 표시 — iOS/데스크톱은 제외.
- (리서치) home_widget 0.9.x는 Android App Widget/iOS·macOS WidgetKit만 지원 — 웹·Windows·Linux 불가. 위젯은 앱이 캐시한 스냅샷을 렌더링할 뿐 SQLite를 직접 읽지 않음.
- (빌드) file_picker 11.0.x는 `isAgp9OrAbove` 분기로 Kotlin 플러그인을 건너뛰어 클래스가 컴파일되지 않음 — 무조건 Kotlin 플러그인을 적용하는 10.3.10으로 다운그레이드하고 API 호출부(`FilePicker.platform.`)도 원복.
- (빌드) flutter_local_notifications 22.x의 desugaring 요구는 기존 의존성의 미해결 빌드 이슈 — 위젯과 무관하나 APK 빌드에 필수라 함께 해결.
- (리뷰) 위젯 XML의 하드코딩 색상(기본 팔레트)·갱신 시 메인 스레드 2회 쿼리는 네이티브 위젯 특성상 허용 가능한 트레이드오프로 판단.
