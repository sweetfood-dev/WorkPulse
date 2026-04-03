# 2026-04-03-edit-past-days-from-detail-surfaces.md

## 상태

- active

## owner

- codex

## 변경 요약

주간 상세와 월간 상세에서 날짜를 선택하면 메인 팝오버 화면으로 돌아가지 않고, 해당 상세 화면 안에서 선택한 날짜의 출근/퇴근 시간을 직접 수정할 수 있게 한다.

## 관련 문서

- [menu-bar-main-popover-overview.md](../../product-specs/menu-bar-main-popover-overview.md)
- [menu-bar-time-editing.md](../../design-docs/menu-bar-time-editing.md)
- [PLANS.md](../../PLANS.md)
- [TDD.md](../../TDD.md)
- [macos-architecture.md](../../macos-architecture.md)

## 행동 변경 (Behavioral Changes - TDD)

- [ ] 주간 상세의 날짜 행을 선택하면 같은 주간 상세 화면 안에서 해당 날짜의 시간 편집 UI가 열린다
- [ ] 월간 상세의 날짜 셀을 선택하면 같은 월간 상세 화면 안에서 해당 날짜의 시간 편집 UI가 열린다
- [ ] 상세 화면 안에서 시간을 저장해도 route는 메인 화면으로 바뀌지 않고 현재 상세 화면에 남는다
- [ ] 상세 화면 안에서 past-date 시간을 저장하면 선택한 날짜 record만 갱신되고 현재 날짜 record는 바뀌지 않는다

## 구조 변경 (Structural Changes - Tidy First)

- [ ] 주간/월간 상세에서 공통으로 재사용할 수 있는 inline 시간 편집 블록을 만든다
- [ ] 상세 날짜 선택 이벤트가 메인 화면 route 전환 대신 현재 detail route 안의 선택 상태를 갱신하게 바꾼다
- [ ] 상세 화면 저장 경로가 선택한 날짜를 직접 upsert하고 같은 detail state를 다시 로드하게 바꾼다

## 테스트 시나리오

- weekly detail: 날짜 선택 시 inline editor 표시, 저장 후 같은 주간 상세 유지
- monthly detail: 날짜 선택 시 inline editor 표시, 저장 후 같은 월간 상세 유지
- persistence: 상세 화면 저장이 선택 날짜 record만 갱신하고 다른 날짜는 바꾸지 않음
- route behavior: 상세 화면에서 저장하거나 취소해도 메인 화면으로 강제 전환되지 않음

## 가정

- 상세 화면에서 날짜를 누르면 별도 신규 편집 화면을 만들지 않고 기존 시간 편집 section을 inline block으로 재사용한다
- 미래 날짜는 이번 범위에서 편집 진입 대상으로 열지 않는다
