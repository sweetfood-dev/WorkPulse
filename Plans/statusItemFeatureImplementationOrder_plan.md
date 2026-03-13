# WorkPulse 상태 아이템 기능 개발 순서 계획 (`statusItemFeatureImplementationOrder_plan.md`)

## 요약
- 이 문서는 개별 요구사항 계획 문서들의 구현 순서를 정의하는 상위 실행 계획이다.
- 목표는 의존성이 낮은 기반 기능부터 쌓고, 그 위에 표시/집계 기능을 단계적으로 올리는 것이다.
- 구현은 항상 `TestGuidance.md` 원칙에 따라 한 번에 하나의 테스트만 추가하며 진행한다.
- 각 단계는 대응하는 개별 `_plan.md`의 체크되지 않은 첫 항목부터 시작한다.

### 목표 (Goal)
메뉴 막대 기반 WorkPulse 기능을 가장 낮은 리스크의 순서로 구현해, 저장 구조와 표시 구조를 안정적으로 쌓으면서 회귀 가능성을 줄인다.

### 제약 사항 (Constraints)
- 구현 순서는 기능 의존성과 테스트 난이도를 기준으로 한다.
- 한 단계가 끝나기 전 다음 단계의 동작 변경을 섞지 않는다.
- 구조 변경은 반드시 해당 단계의 행동 테스트 Green 이후에만 진행한다.
- 개별 요구사항 문서의 범위를 벗어나는 확장은 하지 않는다.

## 구현 순서
1. [menuBarStatusItem_plan.md](/Users/todoc/Desktop/MyProject/WorkPulse/Plans/menuBarStatusItem_plan.md)
- 이유: 모든 후속 UX의 진입점이다. 상태 아이템이 먼저 있어야 클릭 기반 입력/표시 흐름을 올릴 수 있다.

2. [statusItemAttendanceTimeInput_plan.md](/Users/todoc/Desktop/MyProject/WorkPulse/Plans/statusItemAttendanceTimeInput_plan.md)
- 이유: 출근/퇴근시간 저장이 이후 모든 표시 기능의 데이터 기반이다.

3. [statusItemTodayStartTimeDisplay_plan.md](/Users/todoc/Desktop/MyProject/WorkPulse/Plans/statusItemTodayStartTimeDisplay_plan.md)
- 이유: 오늘 기록 조회만으로 구현 가능해 복잡도가 낮고, 저장 구조 검증에도 적합하다.

4. [statusItemWorkedTimeDisplay_plan.md](/Users/todoc/Desktop/MyProject/WorkPulse/Plans/statusItemWorkedTimeDisplay_plan.md)
- 이유: 현재 시각 기준 실시간 계산이 들어가므로 오늘 출근시간 표시보다 복잡하다. 저장 구조가 안정된 뒤 진행하는 편이 안전하다.

5. [statusItemWeeklyWorkedTimeDisplay_plan.md](/Users/todoc/Desktop/MyProject/WorkPulse/Plans/statusItemWeeklyWorkedTimeDisplay_plan.md)
- 이유: 일별 기록 저장 구조를 주 단위 집계로 확장하는 첫 집계 단계다.

6. [statusItemWeeklyFortyHourProgressDisplay_plan.md](/Users/todoc/Desktop/MyProject/WorkPulse/Plans/statusItemWeeklyFortyHourProgressDisplay_plan.md)
- 이유: 주간 총합 계산 결과를 재사용하는 2차 표현 계층이다. 주간 집계가 먼저 안정되어야 한다.

7. [statusItemMonthlyWorkedTimeDisplay_plan.md](/Users/todoc/Desktop/MyProject/WorkPulse/Plans/statusItemMonthlyWorkedTimeDisplay_plan.md)
- 이유: 저장 구조와 기간 집계 패턴이 자리 잡은 뒤 월간 집계로 확장하는 것이 가장 단순하다.

## 단계별 성공 기준
1. 메뉴 막대 진입점이 안정적으로 동작한다.
2. 출근/퇴근시간 입력과 로컬 저장이 검증된다.
3. 오늘 출근시간이 저장값 기준으로 정확히 표시된다.
4. 현재 근무시간이 진행 중/완료 상태를 올바르게 반영한다.
5. 이번 주 누적 근무시간이 기간 경계 포함 정확히 집계된다.
6. 주 40시간 기준 부족/완료/초과 상태가 명확히 표현된다.
7. 이번 달 누적 근무시간이 기간 경계 포함 정확히 집계된다.

## 구현 원칙
1. 각 단계 시작 시 해당 `_plan.md`의 체크되지 않은 첫 행동 변경 항목부터 테스트를 작성한다.
2. 해당 테스트를 통과시키는 최소 코드만 추가한다.
3. Green 이후에만 같은 문서의 구조 변경 항목을 진행한다.
4. 다음 단계로 넘어가기 전에 현재 단계의 빌드 검증 항목을 통과시킨다.
5. 단계 간 공통 로직이 보이면 즉시 추상화하지 말고, 최소 두 단계에서 중복이 확인된 뒤 구조 변경 단계에서 정리한다.

## 명시적 가정 및 기본값
1. 현재 우선순위는 “기능이 보이는 최소 수직 슬라이스”를 빠르게 완성하는 것이다.
2. 집계 기능보다 입력과 단일 표시 기능을 먼저 안정화하는 편이 전체 리스크를 줄인다.
3. 월간 집계는 주간 집계가 검증된 뒤 거의 같은 패턴으로 확장할 수 있다고 가정한다.
