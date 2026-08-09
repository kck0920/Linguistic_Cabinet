# 06 — PLAN.md·knowledge.md 문서 일관성 갱신

Status: resolved

## 요구사항

구현이 PLAN.md 초기 계획과 크게 벗어나면서(캐비닛 테마 도입, SM-2 복습, 6탭 네비게이션, 업적 시스템, 홈 위젯 등) PLAN.md가 실제 코드와 어긋난 상태였다. PLAN.md 전반(구조 트리·의존성·완료 상태·상단 섹션·기능 상세)을 실제 구현 기준으로 재작성하고, knowledge.md의 어긋난 문구도 함께 정정.

## 결정 사항

- **구조 트리**: 실제 `lib/` 기준으로 전면 교체 — feature barrel(`word_feature.dart`)·`providers/` 디렉토리 등 허구 경로 제거, `achievements/`·`dev/`·`home_widget_helper`·`cabinet_theme`·`cabinet_colors`·`format_count` 등 신설 항목 반영. 프로바이더 화면 파일 로컬 정의 관례를 각주로 명시.
- **의존성 패키지**: PLAN의 구식 목록을 실제 `pubspec.yaml` 기준으로 교체 — `flutter_local_notifications 22.1.0`, `home_widget 0.9.3`, `file_picker 10.3.10(고정 사유 주석)`, `share_plus 10`, `timezone`, `sqflite_common_ffi(_web)` 등. 미사용 항목(`intl`, `flutter_slidable`, `flutter_staggered_animations`) 제거.
- **완료 상태**: Phase 7~9 → 이후 Phase 1~9 전 항목에 ✅ 표시. Phase 9는 통합 테스트(신규)·성능 최적화(신규)까지 전 항목 완료로 전환.
- **상단 섹션**: 기술 결정(Riverpod 로컬 정의·sqflite+ffi·테스트 141+1), UI/UX(캐비닛 Neo-Brutal 5모드·6탭·720px 전환), 데이터 모델(Word에 WebP·사전URL, ReviewCard에 SM-2·오버라이드, ReviewLog→StudyLog, settings 키-값) 재작성.
- **기능 상세 점검**: 플래시카드 "입력형+모드 전환"(실제 미존재 → 퀴즈 EXAM 분리 명시), 매칭 "4x4·자유 모드"(실제 4x3·Line Match 2종), 퀴즈 3종→4종 EXAM, 단어 폼에 WebP·네이버 사전·마크다운 메모 추가.
- **knowledge.md**: "PLAN.md 구조 트리 중 실제로 없는 경로 있음" Gotchas → 갱신 완료 문구로 정정.

## 구현 (문서만 변경 — 코드 무수정)

- `PLAN.md` — 구조 트리·의존성·Phase 완료 상태·상단 섹션·기능 상세·설정 항목 전면 갱신
- `knowledge.md` — Current state(테스트 141개 + 통합 테스트 + 성능 최적화)·Gotchas(구조 트리 문구) 갱신

## 검증

- 문서 작업이라 코드 검증 불필요. 실제 `lib/` 구조는 `read_subtree`·`list_directory`로 확인해 트리와 대조 완료.
- 갱신된 정보 기준: `flutter analyze` No issues, `flutter test` 141개(위젯) + 통합 테스트 1개 통과.

## Comments

- (점검) 이전 지식 문서와 달리 `shared/widgets/cabinet_widgets.dart`는 실제 존재 — "shared/widgets 없음"은 잘못된 정보였음.
- (점검) 홈 위젯·리마인더 서비스·home_widget 헬퍼 등 최근 추가 파일이 구조 트리에 누락돼 있었음.
- (점검) Phase 9의 통합 테스트·성능 최적화가 지식 문서상 "미구현"으로 남아 있었으나, 각각 통합 테스트 작성·업적 배치 조회로 완료되어 문서를 실제와 동기화.
