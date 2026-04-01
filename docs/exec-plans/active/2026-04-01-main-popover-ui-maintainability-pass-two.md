# 2026-04-01-main-popover-ui-maintainability-pass-two.md

## 상태

- active

## owner

- codex

## 변경 요약

`MainPopoverViewController`에 남아 있는 테스트 accessor와 UI 보조 타입을 더 분리하고, placeholder/copy/progress policy 경계를 정리한다.

## 관련 문서

- [main-popover-ui-maintainability-pass-two.md](../../product-specs/main-popover-ui-maintainability-pass-two.md)
- [main-popover-ui-maintainability-followup.md](../../product-specs/main-popover-ui-maintainability-followup.md)

## 행동 변경 (Behavioral Changes - TDD)

- [x] current session 계산/갱신 동작 유지
- [x] today time edit/apply/cancel 동작 유지
- [x] weekly/monthly 표시 동작 유지

## 구조 변경 (Structural Changes - Tidy First)

- [x] controller 테스트 accessor 의존을 더 축소
- [x] placeholder copy를 공통 copy 경계로 통합
- [x] current session progress 기본값을 policy로 이동
- [x] view state/runtime/scheduler를 controller 파일 밖으로 분리
- [x] section view/render model 테스트로 구조 검증을 이동
- [x] typography/icon/divider 시각 토큰 검증을 추가

## 진행 상태

- [x] spec 고정
- [x] implementation
- [x] regression verification
