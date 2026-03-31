# 2026-03-31-menu-bar-main-popover-overview.md

## 상태

- active

## owner

- todoc

## 변경 요약

WorkPulse의 첫 제품 구현으로 macOS 메뉴바 상태 아이템과 메인 popover를 추가한다.
popover는 `Current Session`, 오늘 출근/퇴근 시간, 이번 주/이번 달 총 근무 시간을 한눈에 보여주고, 같은 popover 안의 `edit mode`에서 오늘 시간을 수정할 수 있어야 한다.

## 목표와 범위

- 메뉴바 상태 아이템과 main popover shell을 만든다
- `Current Session`을 실시간 또는 고정값으로 올바르게 표시한다
- 오늘 출근/퇴근 시간을 읽기 전용 기본 상태와 같은 popover 안의 edit mode로 제공한다
- 주간/월간 합계를 저장된 기록 기준으로 계산해 표시한다
- 저장 후 현재 세션/집계를 다시 계산한다

## 비목표

- 점심시간 차감
- 주 40시간 진행률/초과 표시
- 월간 캘린더 화면
- 과거 날짜 편집
- 설정 창과 고급 환경설정

## 제약 조건

- macOS 메뉴바 앱 제약을 따른다
- AppKit UI와 runtime wiring은 [`macos-architecture.md`](../../macos-architecture.md)를 따른다
- 중간 상태 없이 검증 가능한 slice로 나눈다
- 시간 계산 규칙은 UI 객체가 아니라 계산 경계가 소유한다
- 집계는 저장된 기록 기준으로만 계산한다

## 관련 문서

- spec: [menu-bar-main-popover-overview.md](../../product-specs/menu-bar-main-popover-overview.md)
- design: [menu-bar-time-editing.md](../../design-docs/menu-bar-time-editing.md)
- architecture: [macos-architecture.md](../../macos-architecture.md)
- shared architecture: [clean-architecture.md](../../clean-architecture.md)

## 명시적 가정

- `Current Session` 형식은 `HH:mm:ss`
- 퇴근 시간이 있으면 `Current Session`은 고정값으로 멈춘다
- 오늘 시간 편집은 auto-save가 아니라 명시적 적용으로 저장한다
- edit mode는 별도 섹션 확장이 아니라 같은 row 위치 전환 방식이다
- 저장되지 않은 편집값은 주간/월간 집계에 포함하지 않는다
- 저장된 기록이 없을 때는 placeholder를 허용한다
- 오늘 기록은 `1일 1기록 upsert`로 저장한다
- 이번 주/이번 달 경계는 로컬 `Calendar`와 `TimeZone` 기준으로 계산한다

## 공개 인터페이스/타입 변경(계획 기준)

- 메뉴바 앱 runtime entry와 status item owner 추가
- 오늘 근무 기록 저장/조회용 protocol 추가
- 현재 세션 계산 경계 추가
- 주간/월간 합계 계산 경계 추가
- popover view state와 edit mode state 추가

## 행동 변경 (Behavioral Changes - TDD)

- [x] macOS 메뉴바 앱 shell이 부트스트랩되고 상태 아이템 클릭으로 main popover가 열린다
- [x] popover 조회 전용 기본 상태가 오늘 출근/퇴근 시간, 이번 주 총합, 이번 달 총합을 한눈에 보여준다
- [x] 오늘 출근 시간만 있으면 `Current Session`이 초 단위로 증가한다
- [x] 오늘 퇴근 시간이 있으면 `Current Session`이 고정값으로 멈춘다
- [x] 주간/월간 합계는 저장된 기록만 기준으로 계산된다
- [ ] 오늘 시간 영역은 기본 상태에서 읽기 전용으로 보인다
- [ ] 사용자가 row를 눌러 같은 위치의 edit mode에 들어가 오늘 출근/퇴근 시간을 수정할 수 있다
- [ ] 사용자가 수정값을 적용하면 오늘 기록, 현재 세션, 주간/월간 합계가 다시 계산된다
- [ ] 사용자가 edit mode를 취소하면 마지막 저장 상태가 유지된다

## 구조 변경 (Structural Changes - Tidy First)

- [x] runtime/ui/service/repo 경계에 맞는 초기 디렉터리/타입 배치를 정한다
- [-] `Date`, `Calendar`, `TimeZone`, timer 의존을 주입 가능한 owner로 분리한다
- [x] 시간 계산과 집계 계산을 AppKit view/controller 밖으로 분리한다
- [-] persistence protocol과 concrete adapter를 분리한다
- [ ] popover 조회 상태와 edit mode 상태 전환을 presentation 계층으로 모은다

## 테스트 케이스 및 시나리오

- 메뉴바 상태 아이템 클릭 시 popover가 열린다
- 오늘 출근 시간 없음 -> `Current Session` placeholder
- 오늘 출근 시간만 있음 -> `Current Session`이 실시간 증가
- 오늘 출근/퇴근 시간 둘 다 있음 -> `Current Session`이 고정 duration 표시
- 이번 주 합계는 저장된 주간 기록만 합산한다
- 이번 달 합계는 저장된 월간 기록만 합산한다
- edit mode 진입 시 입력 UI가 열린다
- edit mode 저장 시 오늘 기록과 요약이 함께 갱신된다
- edit mode 취소 시 변경이 반영되지 않는다

## 진행 상태

- [x] spec 고정
- [x] macOS menu bar shell bootstrap
- [x] popover read-only dashboard
- [x] current session 계산
- [x] weekly/monthly aggregation
- [ ] today time edit mode
- [ ] integration verification
