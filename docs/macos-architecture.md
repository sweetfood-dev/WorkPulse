# macos-architecture.md

## Purpose

이 문서는 WorkPulse의 macOS 애플리케이션 구조를 설명하는 플랫폼 전용 아키텍처 문서입니다.
공통 구조 규칙은 [`clean-architecture.md`](./clean-architecture.md)를 기준으로 보고, 이 문서는 macOS 런타임, AppKit UI, 메뉴바 앱 흐름, 시간/달력 처리, persistence 경계, 테스트 전략까지 포함한 macOS 전용 제약을 다룹니다.

## Read With

- 공통 구조 규칙: [`clean-architecture.md`](./clean-architecture.md)
- 저장소 구조와 문서 라우팅: [`../ARCHITECTURE.md`](../ARCHITECTURE.md)
- 계획과 staged change 기준: [`PLANS.md`](./PLANS.md)
- 제품 판단 기준: [`PRODUCT_SENSE.md`](./PRODUCT_SENSE.md)

## Scope

이 문서는 아래 범위에 적용합니다.

- AppKit 기반 macOS application code
- 메뉴바 상태 아이템, popover, 설정/보조 window
- 시간 입력, 현재 세션, 주간/월간 집계 UI
- app lifecycle, composition root, persistence wiring
- date, calendar, timezone, formatter, timer 처리

이 문서는 아래를 직접 다루지 않습니다.

- 제품 요구사항 자체
- 저장소 전체 문서 라우팅
- 개별 기능의 세부 디자인 rationale

## macOS App Structure

WorkPulse는 macOS 메뉴바 기반 앱을 기본 전제로 둡니다.
따라서 런타임 구조는 일반 document/window 앱보다 아래 기준을 우선합니다.

- app root는 lifecycle과 concrete wiring을 담당합니다.
- status item owner는 메뉴바 진입점을 소유합니다.
- popover flow와 보조 window flow는 필요하면 분리합니다.
- business rule 계산은 UI 객체가 아니라 계산 경계/서비스 뒤에 둡니다.
- 제품 문서와 코드 구조는 메뉴바 앱이라는 제약을 기준으로 설명할 수 있어야 합니다.

## UI Architecture

### AppKit First

- AppKit view, view controller, runtime object는 rendering과 user interaction forwarding에 집중합니다.
- AppKit layer는 출근/퇴근 정책, 점심시간 차감, 집계 규칙을 직접 소유하지 않습니다.
- 표시용 문자열, progress text, footer summary 같은 presentation model은 UI 경계에서 조합합니다.

### Menu Bar And Window Flows

- `NSStatusItem` 생성과 해제는 한 owner가 담당합니다.
- 메뉴바 click handling, popover presentation, 보조 window presentation은 같은 사용자 흐름에 있더라도 책임은 분리합니다.
- 메뉴바 앱 기본 UX와 보조 window UX는 같은 경계에 묶어 두지 않습니다.
- `NSPopover`와 `NSWindow`는 표시 정책이 다르므로 lifecycle과 close handling이 명확해야 합니다.

### View Composition

- `NSView`는 layout과 styling을 담당합니다.
- `NSViewController`는 input binding, display refresh orchestration, lifecycle bridging을 담당합니다.
- `NSApplicationDelegate`는 concrete wiring만 담당하고 화면별 상태 계산을 오래 소유하지 않습니다.

## Time And Calendar Rules

- 현재 시각은 직접 `Date()`를 흩뿌리기보다 provider로 주입합니다.
- `Calendar`, `TimeZone`, `DateFormatter` 의존은 테스트 가능한 owner에 모읍니다.
- 진행 중 세션 계산과 저장된 기록 기반 집계는 가능한 한 같은 정책 객체를 공유합니다.
- 점심시간 차감, 주간 40시간 기준, 월간 집계 규칙은 UI 문구가 아니라 계산 경계가 소유해야 합니다.
- day/week/month 포함 판단은 명시적 matcher 또는 calendar-aware boundary가 담당합니다.

## Persistence Rules

- 출근/퇴근 기록 저장은 protocol 뒤에 둡니다.
- 단일 record 저장과 기간 집계 조회에 필요한 능력은 인터페이스로 명시합니다.
- view controller가 concrete store capability를 런타임 다운캐스트로 발견하는 구조는 피합니다.
- persistence adapter는 `UserDefaults`, file system, DB 같은 concrete storage를 감싸고 바깥에는 앱 도메인 모델/프로토콜만 노출합니다.

## Dependency Boundaries

- Domain과 use case는 `AppKit` 타입을 직접 알지 않아야 합니다.
- Domain과 use case는 `NSStatusItem`, `NSPopover`, `NSWindow`, `NSDatePicker`를 직접 다루지 않습니다.
- Presentation은 raw persistence object나 저장 포맷 자체를 직접 소유하지 않습니다.
- app root/composition root만 concrete dependency wiring을 담당합니다.

## Main Thread And Concurrency

- AppKit UI 갱신은 main thread 또는 `@MainActor`에서만 수행합니다.
- timer callback, async task, background persistence 결과가 UI를 건드릴 때는 actor/thread ownership이 명확해야 합니다.
- long-lived mutable shared state는 임의 singleton보다 명시적 owner 뒤에 둡니다.

## Testing Notes

- 상태 아이템 text/image, popover 표시, 시간 요약 문자열은 characterization test를 둡니다.
- 시간 계산은 clock/calendar/timezone을 주입해 edge case를 검증합니다.
- 임의 sleep보다 controllable timer/date provider를 우선합니다.
- 메뉴바 앱 특성상 window/popup lifecycle 회귀를 최소 smoke 수준으로라도 확인합니다.
- persistence 경계는 저장/수정/기간 집계 시나리오를 분리해 검증합니다.

## Relation To Shared Clean Architecture

- [`clean-architecture.md`](./clean-architecture.md)는 플랫폼 공통 구조 규칙을 정의합니다.
- 이 문서는 WorkPulse의 macOS 전용 보조 규칙입니다.
- 둘이 충돌하면 먼저 공통 구조 규칙을 확인하고, 그다음 macOS 전용 제약을 적용합니다.
