# 2026-04-01-main-popover-ui-maintainability-refactor.md

## 상태

- active

## owner

- codex

## 변경 요약

Stitch UI fidelity를 계속 다듬기 전에 `MainPopover` UI 모듈을 스타일 토큰, render model, section view 중심 구조로 재정리한다.

## 목표와 범위

- 스타일/토큰 분리
- render model / presenter 경계 도입
- current session / today times / summary section view 분리
- section builder 일관화
- 구조 테스트 강화

## 비목표

- 도메인 계산 규칙 변경
- 새 데이터 필드 추가
- snapshot 테스트 도입

## 관련 문서

- [main-popover-ui-maintainability-refactor.md](../../product-specs/main-popover-ui-maintainability-refactor.md)
- [main-popover-stitch-ui-fidelity.md](../../product-specs/main-popover-stitch-ui-fidelity.md)
- [menu-bar-main-popover-overview.md](../../product-specs/menu-bar-main-popover-overview.md)

## 행동 변경 (Behavioral Changes - TDD)

- [x] current session 계산/갱신 동작 유지
- [x] today time edit/apply/cancel 동작 유지
- [x] weekly/monthly 표시 동작 유지

## 구조 변경 (Structural Changes - Tidy First)

- [x] style 토큰을 별도 타입으로 분리
- [x] render model factory를 도입
- [x] section view 3종을 분리
- [x] 일반 section / full-bleed section 조립 경로를 일관화
- [x] 구조 테스트를 강화

## 테스트 케이스 및 시나리오

- progress track은 fill 0이어도 visible token을 가진다
- over-goal에서도 trailing track이 남는다
- today times background는 full-width를 유지한다
- editing action row는 pill 내부가 아니라 별도 row에 있다
- summary two-column alignment가 유지된다
- current session/today times/summary behavior regression이 없다

## 가정

- `MainPopoverViewController` initializer와 테스트 주입점은 유지한다
- semantic/system color 우선 원칙을 사용하되, Stitch 인상을 위해 일부 brand blue는 유지한다

## 진행 상태

- [x] spec 고정
- [x] style 토큰 분리
- [x] render model 분리
- [x] section view 분리
- [x] 구조 테스트 강화
- [x] regression verification
