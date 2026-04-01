# main-popover-ui-maintainability-refactor.md

## 요약

`MainPopoverViewController`에 누적된 레이아웃, 스타일, 편집 상태 표시, 현재 세션 표시 규칙을 분리해 같은 화면을 앞으로 안전하게 다듬을 수 있는 구조로 정리한다.

## 목표

- 스타일 상수와 neutral color 규칙을 한곳에 모은다
- `MainPopoverViewController`가 표시 규칙을 직접 계산하지 않게 한다
- 현재 세션 / 오늘 시간 / 하단 집계 영역을 전용 section view로 분리한다
- 일반 section과 full-bleed background section 조립 경로를 일관화한다
- 구조 테스트를 강화해 UI 회귀를 더 잘 막는다

## 비목표

- current session 계산 규칙 변경
- today time edit/apply/cancel 동작 변경
- weekly/monthly 합계 계산 변경
- snapshot 라이브러리 도입

## 성공 기준

- `MainPopoverViewController`는 section layout 세부와 시각 규칙 대부분을 직접 소유하지 않는다
- current session progress, today times section, summary section이 전용 view로 분리된다
- render model factory가 current session / today time rows / summary 표시 상태를 만든다
- neutral colors는 semantic color 우선으로 정리된다
- 구조 테스트가 progress track, full-width section, action row 분리, summary 정렬을 보호한다
