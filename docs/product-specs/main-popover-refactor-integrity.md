# main-popover-refactor-integrity.md

## 문제와 맥락

메뉴바 메인 popover의 첫 구현은 동작 자체는 갖췄지만, 시간 편집과 저장 경계에 데이터 무결성 리스크가 남아 있다.
현재 구조에서는 잘못된 시간 입력이 집계를 오염시킬 수 있고, 자정 경계에서 저장 대상 날짜가 흔들릴 수 있다.
또한 편집 UI 상태와 AppKit runtime wiring이 컨트롤러에 많이 모여 있어 다음 요구사항 추가 시 변경 범위가 커질 위험이 있다.

## 목표

- 잘못된 시간 입력이 저장/집계에 반영되지 않도록 한다
- popover가 표시 중인 날짜와 저장 대상 날짜를 일치시킨다
- 빈 시간 필드 편집 시 stale picker 값이 다시 나타나지 않게 한다
- 메인 popover의 확장 지점을 더 분명하게 만들어 다음 요구사항 추가 시 변경 범위를 줄인다
- Swift 6 actor isolation 경고를 미래 오류가 되기 전에 정리한다

## 비목표

- 점심시간 차감 규칙 추가
- 주 40시간 진행률 표시
- 과거 날짜 편집 UI 추가
- 캘린더/히스토리 화면 추가
- 메뉴바 popover의 시각 디자인 변경

## 성공 기준

- `endTime < startTime` 입력은 저장되지 않는다
- edit apply는 화면이 표시 중인 record 날짜에 대해 upsert 된다
- 빈 시간 필드 편집 진입 시 picker가 이전 편집의 stale 값을 보여주지 않는다
- 주간/월간 집계는 invalid duration을 누적하지 않는다
- edit mode, 저장, 집계 재계산, runtime wiring의 변경 경계가 더 분명해진다
- `MenuBarPopoverControlling` 관련 Swift 6 actor isolation 경고가 제거된다

## 핵심 사용자/개발자 영향

- 사용자는 잘못된 시간 입력으로 인해 주간/월간 합계를 망가뜨리지 않는다
- 자정 전후 편집에서도 의도한 날짜의 기록만 수정된다
- 후속 요구사항 추가 시 `MainPopoverViewController` 한 곳에 과도하게 수정이 몰리지 않는다

