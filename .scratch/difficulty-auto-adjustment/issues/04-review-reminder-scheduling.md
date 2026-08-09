# 04 — 복습 알림 설정 UI + 시간 예약

Status: resolved

## 요구사항

복습 리마인더는 서비스(`ReviewReminderService`)와 앱 시작 시 즉시 알림만 구현되어 있었고, 설정 화면 UI(켜기/끄기·시간 지정)와 지정 시간 기반 예약(zonedSchedule)이 없어 실질적인 알림 기능으로 동작하지 않았음.

- 설정 > DATA 탭에 복습 알림 토글 + 시간 선택 UI 추가
- 지정 시간에 매일 반복 예약 (`zonedSchedule` + `matchDateTimeComponents: DateTimeComponents.time`)
- 앱 시작·백그라운드 복귀 시 예약 재구성 (재부팅 후에도 유지)

## 결정 사항

- `timezone` 패키지를 전이 의존성에서 직접 의존성으로 승격 (`tz.initializeTimeZones()` 1회 초기화 — `_ensureTz()`).
- `ReviewReminderService.scheduleDailyReminder()` — 활성화면 지정 시간(HH:mm) 매일 반복 예약, 비활성화면 `cancelReminder()`로 취소. 예약 미지원 플랫폼(데스크톱/웹)은 내부 try/catch로 무시.
- `flutter_local_notifications` 22.1.0의 **named 파라미터 API** 사용 (`zonedSchedule(id: …, scheduledDate: …)`, `cancel(id: …)` — 구형 positional 호출은 컴파일 오류).
- 기존 "앱 시작 시 즉시 알림"은 그대로 유지 — 예약 미지원 플랫폼의 폴백 역할.
- 알림 ID 분리: 즉시 알림 0 / 예약 알림 100(`reminderId`) — 충돌 방지.

## 구현

- `pubspec.yaml` — `timezone` 직접 의존성 추가
- `lib/features/settings/data/services/review_reminder_service.dart` — `scheduleDailyReminder`·`cancelReminder`·`_ensureTz`·`getReminderTime`/`setReminderTime`
- `lib/home/home_screen.dart` — `_checkReviewReminder`에 `scheduleDailyReminder()` 추가 (앱 시작·백그라운드 복귀 시 예약 재구성)
- `lib/features/settings/presentation/screens/settings_screen.dart` — DATA 탭 복습 알림 섹션: 토글(`_saveReminderSchedule` → 예약/취소) + 시간 선택 행(`showTimePicker` → `_pickReminderTime` → 재예약)

## 검증

- `flutter analyze` No issues (22.1.0 API로 수정 — 구형 positional 호출 오류 8건 해소)
- `test/review_reminder_service_test.dart` 신규 — 설정 로직(isReminderEnabled/시간 저장) + 스케줄링 안전성(활성·비활성·취소 경로에서 예외 미전파)
- 전체 `flutter test` 135개 통과

## Comments

- (사용자) "자동 백업과 로컬 알림이 있는데 더 좋은 쪽으로 바꿔 준다는거야?" — 제안이 stale knowledge.md 기반이었음을 확인하고 실제 미구현 부분(설정 UI + 시간 예약)만 선별. 자동 백업은 이미 완비로 확인.
- (API) flutter_local_notifications 22.1.0은 named 파라미터 API — `uiLocalNotificationDateInterpretation` 제거, `cancel(id:)`로 수정.
- (설계) zonedSchedule은 Android/iOS 전용 — 데스크톱/웹은 앱 시작 시 즉시 알림 폴백 유지.
