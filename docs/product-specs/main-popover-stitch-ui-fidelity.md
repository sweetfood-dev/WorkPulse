# main-popover-stitch-ui-fidelity.md

## 요약

현재 `MainPopoverViewController`는 기능은 갖췄지만 Stitch 메인 화면의 시각적 위계와 레이아웃을 거의 반영하지 못한다.
이번 작업은 기존 동작을 유지한 채, 메뉴바 메인 popover를 Stitch 기준의 정보 카드 형태로 재구성하는 데 목적이 있다.

## 문제 정의

현재 popover는 기본 `NSStackView`와 라벨 중심의 기술적 placeholder에 가깝다.
사용자는 현재 세션, 오늘 시간, 주간/월간 합계를 볼 수 있지만, 한 glance에 읽히는 시각적 중심이 약하다.

## 목표

- Stitch 메인 화면의 구획 구조를 AppKit popover에 반영한다
- `Current Session`을 화면의 시각적 중심으로 만든다
- 헤더, 현재 세션, 오늘 시간, 집계 영역을 뚜렷하게 구분한다
- 기본 동작과 계산 규칙은 그대로 유지한다
- 읽기 전용 기본 상태와 같은 자리 edit mode를 유지한다

## 비목표

- 새로운 계산 규칙 추가
- 점심시간, 주간 40시간 진행률 같은 새 도메인 기능 추가
- 편집 흐름을 별도 창/패널로 바꾸기
- Stitch 화면의 모바일 비율을 픽셀 단위로 그대로 복제하기

## 성공 기준

- popover를 열면 헤더 / 현재 세션 / 오늘 시간 / 집계 영역이 시각적으로 바로 구분된다
- `Current Session` 영역에 큰 시간 값과 진행 bar가 보인다
- 오늘 시간 영역은 연한 배경의 section 안에서 두 row로 정리된다
- 주간/월간 값은 하단 summary section에 좌우로 정렬된다
- 기존 기능 테스트는 유지된다

## 화면 기준

- Stitch project: `4219850670905370573`
- Stitch screen: `Work Hours Tracker with Calendar View`

## 구현 원칙

- 기능을 바꾸지 않고 레이아웃과 스타일만 개선한다
- AppKit 기본 요소를 우선 사용하고, 필요한 최소 layer styling만 추가한다
- 테스트는 핵심 텍스트/상호작용 보존에 집중하고 픽셀 단위 검증은 하지 않는다
