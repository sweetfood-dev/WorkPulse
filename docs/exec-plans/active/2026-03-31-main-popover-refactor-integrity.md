# 2026-03-31-main-popover-refactor-integrity.md

## 상태

- active

## owner

- todoc

## 변경 요약

메뉴바 메인 popover 구현 이후 남아 있는 데이터 무결성, 유지보수성, Swift 6 호환성 리스크를 줄이는 후속 refactor를 진행한다.
이번 작업은 동작 확장이 아니라 잘못된 저장/집계 가능성을 줄이고, 이후 변경의 surface area를 좁히는 것이 목표다.

## 목표와 범위

- invalid time edit 저장 차단
- popover가 표시 중인 날짜 기준으로 today record upsert
- 빈 필드 편집 시 stale picker 값 제거
- invalid stored record가 집계를 오염시키지 않도록 방어
- 현재 popover 편집/저장 경계를 더 분명하게 분리
- 메뉴바 popover protocol의 actor isolation 계약 정리

## 비목표

- 새로운 제품 기능 추가
- 점심시간 차감 정책 도입
- 과거 날짜 편집 도입
- popover 디자인 재작업

## 제약 조건

- 기능 동작을 새로 넓히지 않는다
- refactor는 작은 Green slice로만 진행한다
- 구조 변경과 행동 변경을 가능하면 분리한다
- AppKit/runtime 의존 조정은 [`macos-architecture.md`](../../macos-architecture.md)를 따른다

## 관련 문서

- spec: [main-popover-refactor-integrity.md](../../product-specs/main-popover-refactor-integrity.md)
- design: [main-popover-refactor-boundaries.md](../../design-docs/main-popover-refactor-boundaries.md)
- previous feature plan: [2026-03-31-menu-bar-main-popover-overview.md](./2026-03-31-menu-bar-main-popover-overview.md)
- architecture: [macos-architecture.md](../../macos-architecture.md)

## 명시적 가정

- invalid time edit는 저장 거부가 우선이고, 이번 slice에서는 별도 에러 메시지 UI까지 추가하지 않는다
- 빈 필드 편집의 기본 picker 값은 stale 값만 아니면 된다
- invalid persisted record는 집계에서 제외하는 방어 규칙을 둔다
- actor isolation 정리는 테스트 경고 제거가 목적이지만, production protocol contract도 함께 맞춘다

## 행동 변경 (Behavioral Changes - TDD)

- [x] `endTime < startTime`인 수정값은 저장되지 않는다
- [x] 자정 경계 이후에도 edit apply는 popover가 표시 중인 날짜의 record를 수정한다
- [x] 빈 시간 필드 편집 진입 시 picker는 이전 편집의 stale 값을 보여주지 않는다
- [x] invalid stored record는 주간/월간 집계에서 제외된다

## 구조 변경 (Structural Changes - Tidy First)

- [x] today edit validation 경계를 명시적으로 둔다
- [x] popover가 표시 중인 reference date를 저장 경로에서 명시적으로 소유한다
- [x] picker 값 동기화 책임을 stale-state 제거 규칙과 함께 분리한다
- [ ] `MenuBarPopoverControlling` isolation 계약을 명시한다
- [ ] `MainPopoverViewController` 책임 분리의 다음 진입점을 정리한다

## 테스트 케이스 및 시나리오

- end time이 start time보다 이르면 apply callback이 호출되지 않는다
- 자정 후 apply해도 원래 표시 중인 날짜 record가 upsert 된다
- nil end time 상태에서 edit mode를 다시 열어도 stale picker 값이 보이지 않는다
- invalid stored record는 weekly/monthly total 계산에서 제외된다
- 메뉴바 popover test fake가 Swift 6 isolation 경고 없이 protocol을 구현한다

## 진행 상태

- [x] spec 고정
- [x] invalid time edit 차단
- [x] displayed reference date 보존
- [x] stale picker reset
- [x] totals defensive guard
- [ ] actor isolation cleanup
- [ ] integration verification
