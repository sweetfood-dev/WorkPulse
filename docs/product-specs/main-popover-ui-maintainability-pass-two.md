# main-popover-ui-maintainability-pass-two.md

## 목적

메인 팝오버 UI 리팩터링 이후에도 남아 있는 controller 중심성과 copy/progress policy 경계를 더 줄인다.

## 범위

- controller 테스트용 accessor 축소
- placeholder copy를 `MainPopoverCopy` 경계로 흡수
- current session progress 기본값을 policy로 이동
- `MainPopoverViewState`, current session runtime, scheduler protocol을 별도 파일로 분리
- section view/render model 테스트로 검증 이동
- 시각 토큰 검증 보강

## 비범위

- 사용자-facing 동작 변경
- snapshot 테스트 도입
- 새로운 appearance 모드 추가
