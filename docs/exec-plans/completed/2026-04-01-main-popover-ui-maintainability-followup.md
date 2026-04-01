# 2026-04-01-main-popover-ui-maintainability-followup.md

## 상태

- active

## owner

- codex

## 변경 요약

메인 팝오버 UI 리팩터링 후 남은 section-file 집중도, controller 테스트 결합, copy/progress policy 경계를 후속 정리한다.

## 관련 문서

- [main-popover-ui-maintainability-followup.md](../../product-specs/main-popover-ui-maintainability-followup.md)
- [main-popover-ui-maintainability-refactor.md](../../product-specs/main-popover-ui-maintainability-refactor.md)

## 행동 변경 (Behavioral Changes - TDD)

- [x] current session 계산/갱신 동작 유지
- [x] today time edit/apply/cancel 동작 유지
- [x] weekly/monthly 표시 동작 유지

## 구조 변경 (Structural Changes - Tidy First)

- [x] section view 파일을 최소 둘 이상으로 분리
- [x] controller 테스트 accessor 의존 축소
- [x] copy 상수 묶음 분리
- [x] current session progress policy 분리
- [x] section view 단위 구조 테스트 추가

## 진행 상태

- [x] spec 고정
- [x] implementation
- [x] regression verification
