# VocaTree Context

VocaTree는 모든 플랫폼에서 사용 가능한 영어 단어장 앱입니다. 단어 등록, 학습, 퀴즈, 매칭을 통해 영어 어휘력을 키우는 것이 목표입니다.

## Language

### 핵심 도메인

**단어 (Word)**:
영어 단어와 그 뜻(한국어)을 하나의 쌍으로 저장한 학습 대상.
_AVOID_: 어휘, 용어, entry

**단어장 (WordBook)**:
사용하지 않음. 단어는 태그로 분류하며 별도 컨테이너 없음.
_AVOID_: vocabulary, deck

**태그 (Tag)**:
단어에 붙이는 자유 형식 키워드. 주제별 분류(비즈니스, 여행 등)에 사용. 하이브리드 방식: 기본은 문자열 키워드, 자주 쓰는 태그는 자동완성 목록으로 관리.
_AVOID_: category, label

**난이도 (Difficulty)**:
단어의 난이도 레벨(1-5). 복습 스케줄 계산에 반영됨. 높은 난이도는 더 자주 반복.

### 학습 시스템

**학습 세션 (StudySession)**:
사용자가 플래시카드를 넘기거나 퀴즈를 푸는 행위 자체.
_AVOID_: 복습, 연습, review

**학습 스케줄 (StudySchedule)**:
학습 간격을 계산하는 로직. 레이니어/고정 간격/SM-2 중 하나의 방식 적용. 단어별 오버라이드 가능.
_AVOID_: 복습 간격, 리뷰 스케줄, review schedule

**학습 이력 (StudyLog)**:
某 회 학습의 정답/오답 기록. 플래시카드와 퀴즈 결과가 기록됨. 매칭은 기록하지 않음.
_AVOID_: 복습 기록, 리뷰 로그, review log

### 학습 방식

**레이니어 (Linear)**:
학습 스케줄 방식 중 하나. 간격 단계를 난이도에 따라 조절함. 기본: 1일→3일→7일→30일.
_AVOID_: linear review

**고정 간격 (Fixed)**:
학습 스케줄 방식 중 하나. 매일/2일/3일/7일/14일/30일 중 하나를 고정으로 사용.
_AVOID_: fixed review

**SM-2**:
학습 스케줄 방식 중 하나. easiness_factor/interval/repetition으로 동적 간격 계산. 슈퍼메모리 알고리즘 기반.
_AVOID_: SuperMemo, SR

### 학습 도구

**플래시카드 (Flashcard)**:
단어를 카드로 보여주고 탭/스와이프로 학습하는 도구. 기본형(뒤집기)과 입력형(타이핑) 모드 존재.
_AVOID_: card

**퀴즈 (Quiz)**:
객관식/빈칸 채우기 형태로 학습하는 도구. 정답/오답이 학습 이력에 기록됨.
_AVOID_: test, exam

**매칭 (Matching)**:
카드를 뒤집어 단어-뜻 짝을 맞추는 게임. 학습 이력에 기록되지 않음.
_AVOID_: game, memory game

**뜻 타이핑 (MeaningTyping)**:
영어 단어를 보고 한국어 뜻을 직접 타이핑하는 전용 학습 화면. 부분 일치 허용.
_AVOID_: meaning quiz

**철자 타이핑 (SpellingTyping)**:
한국어 뜻을 보고 영어 단어를 직접 타이핑하는 전용 학습 화면. 오타 허용 범위 설정 가능.
_AVOID_: spelling quiz, fill blank

### 데이터 관리

**백업 (Backup)**:
단어장 데이터를 ZIP 또는 JSON으로 내보내기/가져오기. ZIP은 이미지 포함, JSON은 순수 텍스트.
_AVOID_: export, import

**자동 백업 (AutoBackup)**:
앱 시작 시 자동으로 백업 파일을 생성하는 기능.
_AVOID_: auto save
