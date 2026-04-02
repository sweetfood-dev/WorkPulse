# 2026-04-02-weekend-korean-holiday-detail.md

## 상태

- active

## owner

- codex

## 변경 요약

월간/주간 상세에 공통 `CalendarDayMetadataProvider`를 도입해 주말, 한국 공휴일, 대체공휴일을 같은 규칙으로 분류하고, 셀/행 안에 휴일명과 대체공휴일 설명을 노출한다.

## 관련 문서

- [menu-bar-main-popover-overview.md](../../product-specs/menu-bar-main-popover-overview.md)
- [PLANS.md](../../PLANS.md)
- [macos-architecture.md](../../macos-architecture.md)

## 행동 변경 (Behavioral Changes - TDD)

- [ ] 월간 상세에서 주말 근무 데이터가 숨지지 않고 계속 `worked` 또는 `active`로 표시된다
- [ ] 월간 상세에서 기록 없는 주말은 평일과 다른 색으로 표시된다
- [ ] 월간/주간 상세에서 한국 공휴일과 대체공휴일이 별도 색으로 강조되고 이름이 보인다
- [ ] 대체공휴일일 때 원 휴일명이 함께 표시된다

## 구조 변경 (Structural Changes - Tidy First)

- [ ] `CalendarDayMetadataProviding`와 한국 공휴일 번들형 provider를 추가한다
- [ ] `MainPopoverRuntimeDependencies`에서 provider를 주입해 월간/주간 loader가 공유하도록 만든다
- [ ] 월간/주간 상세 state를 activity와 day category로 분리한다
- [ ] 월간/주간 상세 UI를 2줄 annotation 레이아웃과 day category styling으로 확장한다

## 테스트 시나리오

- provider: 고정 공휴일, 음력 공휴일, 대체공휴일, 서울 timezone 경계
- monthly loader: 주말 근무일, 주말 무기록일, 공휴일 무기록일, 대체공휴일 annotation
- weekly loader: 주간 7행 유지, holiday annotation 추가, total/progress 회귀 없음
- view/controller: 월간 셀과 주간 row의 annotation 렌더링, navigation 회귀 없음
- runtime wiring: `MainPopoverRuntimeDependencies` fixture 갱신

## 가정

- holiday 데이터는 오프라인 번들형으로 유지하고, 임시 공휴일 자동 동기화는 이번 범위에 포함하지 않는다
- 대체공휴일 표기는 `<원휴일명> 대체공휴일` 형식으로 고정한다
