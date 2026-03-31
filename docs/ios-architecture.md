# ios-architecture.md

## Purpose

이 문서는 [`clean-architecture.md`](./clean-architecture.md)를 iOS/Swift 코드에 적용할 때 필요한 플랫폼 전용 보조 규칙을 정의합니다.
공통 구조 규칙은 shared clean architecture 문서를 기준으로 보고, 이 문서는 Apple 플랫폼에서 추가로 필요한 UI, navigation, concurrency, testing 제약만 다룹니다.

## Read With

- 공통 구조 규칙: [`clean-architecture.md`](./clean-architecture.md)
- 프론트엔드 공통 기준: [`FRONTEND.md`](./FRONTEND.md)

## Scope

이 문서는 아래 범위에 적용합니다.

- UIKit / SwiftUI 기반 iOS feature
- ViewController, SwiftUI View, ViewModel, Presenter, Coordinator, Router
- Swift concurrency를 사용하는 iOS application code

## iOS Presentation Rules

- ViewController와 SwiftUI View는 rendering, binding, user input forwarding에 집중합니다.
- ViewModel 또는 Presenter는 화면 상태를 소유하고 use case input/output을 화면용 상태로 번역합니다.
- 표시용 formatting, sectioning, cell/view state 조합은 Presentation boundary에서 처리합니다.
- 화면 이동은 Presentation/Coordinator/router 쪽에서 결정합니다.

## Framework Leakage Rules

- Domain과 UseCase는 `UIKit`, `SwiftUI`, `Combine`, `CoreData`, `URLSession` 같은 프레임워크 타입을 직접 알지 않아야 합니다.
- Presentation은 raw DTO, persistence object, DB row를 직접 다루지 않습니다.
- ViewModel이 API client, DB client, analytics SDK를 직접 생성하거나 소유하지 않습니다.

## Swift Concurrency Rules

### Main Actor Default

- 화면 상태를 직접 소유하는 ViewModel, Presenter, UI-facing adapter는 기본적으로 `@MainActor`를 기본값으로 둡니다.
- 예외가 있으면 왜 main-actor isolated가 아닌지 설명할 수 있어야 합니다.
- ViewController와 SwiftUI View 업데이트는 main actor에서만 일어납니다.

### Actor Isolation And Shared State

- UseCase는 기본적으로 `@MainActor`가 아니어야 하며 UI framework와 무관한 상태를 유지합니다.
- long-lived mutable shared state는 임의의 class singleton에 두지 말고 actor 또는 명시적 직렬화 소유자 뒤에 둡니다.
- actor isolation이 필요한 타입은 호출자에게 암묵적 thread assumption을 요구하지 않아야 합니다.

### Sendable And Boundary Safety

- actor/task boundary를 실제로 넘는 request/response model과 async payload는 가능하면 `Sendable`이어야 합니다.
- repository, gateway, async service contract는 concurrency boundary를 호출자에게 숨기지 않도록 설계합니다.

### Structured Concurrency First

- request-scoped 병렬 작업은 가능하면 `async let` 또는 task group 같은 structured concurrency를 기본값으로 둡니다.
- unstructured `Task {}`는 lifecycle owner가 분명할 때만 사용합니다.
- `Task.detached`는 actor inheritance와 cancellation propagation을 의도적으로 끊어야 할 때만 사용합니다.

### Cancellation

- child task는 호출자의 cancellation을 가능한 한 그대로 전파합니다.
- long-running use case, adapter, infrastructure call은 cooperative cancellation check point를 의도적으로 둡니다.
- retry, debounce, user-driven cancellation은 Presentation/Application 경계에서 의도적으로 다룹니다.

## iOS Navigation And Composition

- feature별 assembler 또는 composition root에서 concrete wiring을 수행합니다.
- cross-feature dependency는 app root 또는 상위 composition root에서만 연결합니다.
- Coordinator/router는 화면 흐름을 담당하지만 business policy를 소유하지 않습니다.

## iOS Testing Notes

- Presentation 테스트는 state transition, intent handling, loading/error/empty/success 상태를 검증합니다.
- clock, scheduler, network, file system은 주입해서 테스트하고 임의 sleep에 기대지 않습니다.
- actor 또는 serialized owner가 있는 타입은 concurrent access 시나리오를 최소 한 번 검증합니다.
- platform-native test framework를 쓰더라도 architecture boundary 기준은 shared clean architecture 문서를 따릅니다.

## Relation To Shared Clean Architecture

- [`clean-architecture.md`](./clean-architecture.md) 는 플랫폼 공통 구조 규칙을 정의합니다.
- 이 문서는 그 위에 올라가는 iOS/Swift 보조 규칙입니다.
- 둘이 충돌하면 먼저 공통 구조 규칙을 확인하고, 그다음 iOS 전용 제약을 적용합니다.
