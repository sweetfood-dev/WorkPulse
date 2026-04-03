# 2026-04-03-edit-past-days-from-detail-surfaces.md

## 상태

- active

## owner

- codex

## 변경 요약

주간 상세와 월간 상세에서 날짜를 선택하면 같은 popover 안의 기존 메인 시간 편집 화면으로 돌아가 해당 날짜의 출근/퇴근 시간을 수정할 수 있게 한다.

## 관련 문서

- [menu-bar-main-popover-overview.md](../../product-specs/menu-bar-main-popover-overview.md)
- [menu-bar-time-editing.md](../../design-docs/menu-bar-time-editing.md)
- [PLANS.md](../../PLANS.md)
- [TDD.md](../../TDD.md)
- [macos-architecture.md](../../macos-architecture.md)

## 행동 변경 (Behavioral Changes - TDD)

- [x] 주간 상세의 날짜 행을 선택하면 메인 화면으로 돌아가 해당 날짜 기록을 편집할 수 있다
- [x] 월간 상세의 날짜 셀을 선택하면 메인 화면으로 돌아가 해당 날짜 기록을 편집할 수 있다
- [x] 과거 날짜를 선택했을 때 current session은 실시간으로 갱신되지 않고 저장된 상태만 표시된다
- [x] 과거 날짜를 편집해 저장하면 선택한 날짜 record가 갱신되고 현재 날짜 record는 바뀌지 않는다

## 구조 변경 (Structural Changes - Tidy First)

- [x] 주간/월간 상세 day view state에 선택 대상 날짜를 포함한다
- [x] 상세 화면 selection 이벤트를 coordinator까지 연결한다
- [x] main popover display intent에 past-date current session 정책을 포함한다

## 테스트 시나리오

- weekly detail section: 날짜 선택 이벤트 전달
- monthly detail view: 날짜 선택 이벤트 전달과 outside-month/future 비선택
- coordinator/view controller: 선택 날짜를 메인 화면으로 열고 해당 reference date를 저장 대상으로 사용
- current session: 과거 날짜에서 live scheduler 미시작, end time 있을 때만 fixed duration 표시

## 가정

- 상세 화면에서 날짜를 누르면 별도 신규 편집 UI를 열지 않고 기존 메인 popover 편집 흐름을 재사용한다
- 미래 날짜는 이번 범위에서 편집 진입 대상으로 열지 않는다
