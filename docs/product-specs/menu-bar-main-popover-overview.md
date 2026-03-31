# menu-bar-main-popover-overview.md

## 요약

WorkPulse의 첫 메인 UI는 macOS 메뉴바 상태 아이템을 눌렀을 때 열리는 popover다.
이 popover는 오늘의 근무 상태를 한눈에 읽게 하는 상태판이면서, 오늘 출근/퇴근 시간을 같은 표면 안에서 수정할 수 있어야 한다.
시각적 방향은 Stitch 프로젝트의 메인 화면을 기준으로 한다.

- Stitch reference: `Work Hours Tracker App Concept`
- project: `4219850670905370573`
- main screen: `Work Hours Tracker with Calendar View`

## 문제 정의

사용자는 메뉴바에서 앱을 여는 즉시 아래 질문에 답할 수 있어야 한다.

- 지금 오늘 몇 시간째 일하고 있는가
- 오늘 출근/퇴근 시간이 어떻게 기록되어 있는가
- 이번 주에 얼마나 일했는가
- 이번 달에 얼마나 일했는가

현재 목표는 이 정보를 `한 화면, 한 glance` 안에서 읽고, 오늘 시간 기록만 짧은 수정 흐름으로 바로 고칠 수 있게 만드는 것이다.

## 대상 사용자

- 자신의 근무 시간을 빠르게 확인하고 싶은 macOS 사용자
- 별도 메인 창을 열지 않고 메뉴바에서 오늘 기록을 조정하고 싶은 사용자

## 목표

- 메뉴바 상태 아이템 클릭 시 메인 popover를 연다
- popover 안에 아래 정보를 동시에 보여준다
  - `Current Session`
  - 오늘 출근 시간
  - 오늘 퇴근 시간
  - 이번 주 총 근무 시간
  - 이번 달 총 근무 시간
- `Current Session`은 오늘 출근 시간부터 현재 시각까지 실시간으로 증가한다
- 오늘 퇴근 시간이 있으면 `Current Session`은 퇴근 시각 기준의 고정값으로 멈춘다
- 오늘 출근/퇴근 시간은 같은 popover 안에서 수정할 수 있다
- 주간/월간 합계는 저장된 근무 기록 기준으로 계산한다

## 비목표

- 점심시간 차감 규칙
- 주 40시간 진행률/초과시간 표시
- 월간 캘린더 화면
- 설정 창, 환경설정, 다중 화면 흐름
- 과거 날짜 기록 직접 수정

## 성공 기준

- 사용자가 popover를 열면 오늘 상태를 1초 안에 읽을 수 있다
- `Current Session`은 출근만 기록된 동안 초 단위로 갱신된다
- 퇴근 시간이 입력되면 `Current Session`이 더 이상 증가하지 않는다
- 출근/퇴근 시간을 수정해 저장하면 화면의 오늘 기록과 집계가 일관되게 다시 계산된다
- 사용자는 별도 메인 창 없이 popover 안에서 오늘 기록 수정까지 끝낼 수 있다

## 핵심 사용자 흐름

### 1. 기본 조회

1. 사용자가 메뉴바 상태 아이템을 클릭한다
2. popover가 열린다
3. 사용자는 아래를 한 번에 본다
   - 날짜/오늘 상태 헤더
   - `Current Session`
   - 오늘 출근/퇴근 시간
   - 이번 주 총 근무 시간
   - 이번 달 총 근무 시간

### 2. 오늘 시간 수정

1. 사용자가 `Start Time` 또는 `End Time` 영역에서 수정 흐름에 들어간다
2. 선택한 row가 같은 자리에서 시간 입력 가능한 `edit mode`로 전환된다
3. 사용자가 출근/퇴근 시간을 바꾼다
4. 사용자가 명시적으로 적용한다
5. popover는 조회 상태로 돌아오고, 오늘 기록/현재 세션/주간/월간 요약을 다시 계산한다

## 화면 구성

### 헤더

- 오늘 날짜 표시
- 오늘 출근 기록이 있으면 `Checked in at HH:mm` 요약 표시

### Current Session 영역

- popover에서 가장 눈에 띄는 값이다
- 형식은 `HH:mm:ss`
- 오늘 출근 시간만 있고 퇴근 시간이 없으면 실시간으로 증가한다
- 오늘 퇴근 시간이 있으면 `endTime - startTime`의 고정값을 표시한다

### 오늘 시간 영역

- `Start Time`
- `End Time`
- 기본 상태는 읽기 전용이다
- 수정은 같은 popover 안의 `edit mode`로 들어가서 수행한다
- edit mode는 별도 하단 패널을 여는 방식이 아니라, 선택한 row가 같은 위치에서 편집 상태로 전환되는 방식이다
- 편집 중에도 `Current Session`, 주간 합계, 월간 합계 영역은 계속 보인다

### 집계 영역

- `This Week`
- `This Month`
- 각각 저장된 근무 기록 기준의 총합을 보여준다
- 진행 중인 오늘 세션은 저장되기 전까지 집계에 포함하지 않는다

## 계산 및 상태 규칙

### Current Session

- 입력
  - 오늘 출근 시간
  - 오늘 퇴근 시간
  - 현재 시각
- 규칙
  - 출근 시간 없음: placeholder
  - 출근 시간만 있음: `now - startTime`
  - 출근/퇴근 시간 둘 다 있음: `endTime - startTime`

### 주간/월간 합계

- 저장된 기록만 사용한다
- 오늘 화면에서 아직 저장하지 않은 편집값은 포함하지 않는다
- 오늘 편집을 저장한 뒤에는 해당 기록 기준으로 다시 계산한다
- 이번 주 경계는 사용자 로컬 `Calendar`의 `weekOfYear` 기준으로 판단한다
- 이번 달 경계는 사용자 로컬 `Calendar`와 `TimeZone` 기준으로 판단한다

### 오늘 기록 저장 모델

- 오늘 기록은 `1일 1기록`으로 본다
- 오늘 출근/퇴근 시간을 수정해 저장하면 해당 날짜 record를 upsert한다
- 같은 날짜에 이미 저장된 기록이 있으면 새 값으로 교체한다

## 상호작용 기본값

- 오늘 시간 영역은 항상 inline editable로 두지 않는다
- 기본 상태는 읽기 전용 dashboard다
- 수정은 같은 popover 안의 `edit mode`에서만 가능하다
- 저장은 auto-save가 아니라 명시적 적용 액션으로 수행한다
- 취소하면 직전 저장 상태를 유지한다

## placeholder 기본값

- 출근 시간이 없으면 `Current Session`은 placeholder를 표시한다
- 퇴근 시간이 없으면 `End Time`은 미입력 상태를 표시한다
- 주간/월간 저장 기록이 없으면 각각 placeholder를 표시한다

## 디자인 기준

- 시각적 방향은 Stitch 메인 popover 화면을 따른다
- 기본 경로는 `빠른 확인`이어야 한다
- `수정`은 지원하지만 기본 읽기 흐름을 방해하지 않아야 한다
- `Current Session`이 화면의 시각적 중심이어야 한다

## 관련 문서

- [PLANS.md](../PLANS.md)
- [DESIGN.md](../DESIGN.md)
- [macos-architecture.md](../macos-architecture.md)
- [menu-bar-time-editing.md](../design-docs/menu-bar-time-editing.md)
