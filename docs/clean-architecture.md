# clean-architecture.md

## Purpose

이 문서는 플랫폼에 종속되지 않는 공통 `Clean Architecture` 운영 규칙을 정의합니다.
저장소 수준 구조는 `ARCHITECTURE.md`가 설명하고, 플랫폼 전용 제약은 각 플랫폼 문서가 설명합니다.

## Read With

- 저장소 구조와 문서 라우팅: [`../ARCHITECTURE.md`](../ARCHITECTURE.md)
- 프론트엔드 공통 기준: [`FRONTEND.md`](./FRONTEND.md)
- macOS 전용 보조 규칙: [`macos-architecture.md`](./macos-architecture.md)

## Scope

이 문서는 아래 범위에 적용합니다.

- 새로 만드는 feature/module
- 리팩터링 대상이 되는 기존 feature/module
- Presentation, Application/UseCase, Domain, Data/Interface Adapters, Infrastructure 경계를 가지는 코드
- 경계 간 데이터 이동, 조립 지점, 테스트 seam 판단

이 문서는 아래를 직접 다루지 않습니다.

- 특정 UI 프레임워크의 세부 API
- 특정 언어의 동시성 문법
- 저장소 전체의 문서 구조
- 제품 요구사항 자체

## Core Principles

- 의존성은 바깥에서 안쪽으로만 향합니다.
- 안쪽 레이어는 바깥 구현 세부사항의 이름과 형식을 몰라야 합니다.
- Use Case는 사용자 의도 단위의 응용 경계입니다.
- Data / Interface Adapters는 바깥 데이터와 안쪽 모델 사이의 번역 경계입니다.
- Infrastructure는 가장 바깥에서 concrete capability를 제공합니다.
- 구조는 framework가 아니라 feature와 use case를 먼저 드러내야 합니다.

## Dependency Rule

### Allowed Direction

- `Presentation -> Application/UseCase`
- `Application/UseCase -> Domain`
- `Application/UseCase -> Repository Protocol / Gateway Protocol / Output Boundary`
- `Data / Interface Adapters -> Repository Protocol / Gateway Protocol / Output Boundary`
- `Data / Interface Adapters -> Domain`
- `Data / Interface Adapters -> Infrastructure`
- `Composition Root -> Presentation / Application / Data / Infrastructure`

### Forbidden Direction

- `Domain -> UI framework / transport framework / persistence framework`
- `Domain -> View / ViewModel / Presenter / Router`
- `UseCase -> concrete API client / concrete DB / concrete file system`
- `UseCase -> UI navigation / UI rendering detail`
- `Presentation -> persistence model / raw DTO`

### Practical Meaning

- 안쪽 레이어는 정책을 소유하고, 바깥 레이어는 세부 구현을 소유합니다.
- 의존성 역전의 목적은 추상화 수를 늘리는 것이 아니라 정책을 세부사항에서 보호하는 것입니다.
- 어떤 타입이 안쪽 경계에 들어오면 그 타입의 이름과 형식이 구조를 오염시키지 않는지 먼저 봅니다.

## Machine Layer Model

이 starter는 Clean Architecture의 핵심 경계를 lint 가능한 구현 레이어로 투영합니다.
기계 검증의 기본 레이어는 아래 순서를 따릅니다.

- `types`
- `config`
- `domain`
- `repo`
- `service`
- `runtime`
- `ui`

이 레이어 모델은 개념 자체를 단순화하려는 목적이 아니라, high-confidence subset을 기계적으로 강제하기 위한 모델입니다.
구현 방법은 자유롭게 둘 수 있지만, 경계와 의존성 방향은 엄격하게 유지합니다.

권장 해석은 아래와 같습니다.

- `types`: boundary model, contract, simple value type
- `config`: flag, policy constant, environment/config decoding
- `domain`: entity, value object, domain rule
- `repo`: repository implementation, DTO, mapper, data adapter
- `service`: use case, application orchestration
- `runtime`: composition root, app lifecycle, job/handler wiring
- `ui`: view, controller, presenter, view model, route trigger

## Layer Responsibilities

### Presentation

Presentation은 사용자 입력, 화면 상태, 표시 모델, navigation trigger를 다룹니다.

소유하는 것:

- view/screen, presenter/view model, 화면 상태
- 사용자 이벤트 처리
- 표시용 formatting과 aggregation
- navigation trigger

소유하면 안 되는 것:

- 핵심 비즈니스 규칙
- 네트워크/영속성 세부사항
- raw DTO / persistence model 직접 사용

핵심 규칙:

- Presentation은 사용자 intent를 use case 입력으로 번역합니다.
- 표시용 모델이 필요하면 Presentation boundary에서 만듭니다.
- 화면 이동 결정은 Presentation 계층 또는 그 보조 계층이 담당합니다.

### Application / UseCase

UseCase는 하나의 사용자 의도 또는 응용 시나리오를 실행하는 계층입니다.

소유하는 것:

- 사용자 의도 단위 orchestration
- 트랜잭션 경계
- 여러 repository/gateway 호출 조합
- 실패를 응용 의미로 변환하는 것

소유하면 안 되는 것:

- UI framework 의존
- navigation 세부사항
- concrete networking/storage 구현
- 화면용 formatting

핵심 규칙:

- UseCase는 얇은 pass-through wrapper가 아니라 의미 있는 응용 경계여야 합니다.
- UseCase 이름은 가능하면 사용자 의도 중심의 동사형으로 둡니다.
- God UseCase로 커지지 않도록 unrelated 행동을 섞지 않습니다.

### Domain

Domain은 가장 안정적인 핵심 규칙을 담는 곳입니다.

소유하는 것:

- Entity
- Value Object
- Domain Rule
- 상태 전이 규칙
- 비즈니스 불변 조건

소유하면 안 되는 것:

- UI framework 타입
- API 응답 DTO
- persistence object
- analytics, logging, navigation

핵심 규칙:

- Domain model은 외부 데이터 형식과 분리합니다.
- Domain은 가능한 한 platform-agnostic하게 유지합니다.

### Data / Interface Adapters

이 계층은 외부 데이터와 내부 모델 사이의 번역 경계입니다.

소유하는 것:

- DTO
- request/response mapping
- persistence object mapping
- repository/gateway implementation
- 외부 에러를 앱 내부 의미로 번역하는 로직

소유하면 안 되는 것:

- 화면 상태
- UI navigation
- domain rule 자체

핵심 규칙:

- Mapper는 경계에서만 존재해야 합니다.
- raw DTO, persistence object, framework-shaped model이 안쪽 경계로 새면 안 됩니다.
- repository implementation은 이 경계에 두고, concrete client는 Infrastructure에서 주입받습니다.

### Infrastructure

Infrastructure는 외부 시스템 접근을 담당합니다.

소유하는 것:

- API client
- DB / file / queue / cache driver
- analytics, push, background integration
- framework-specific integration

소유하면 안 되는 것:

- business policy
- domain rule
- 사용자 의도 단위 흐름 결정

핵심 규칙:

- Infrastructure는 가장 바깥에서 세부 구현을 제공합니다.
- Infrastructure는 contract를 직접 소유하지 않고, adapter가 사용할 concrete capability를 제공합니다.

## Core Building Blocks

### Entity

- 시스템 핵심 개념을 나타내는 모델
- transport/persistence 형태와 분리됨
- business invariant를 품을 수 있음

### Value Object

- identity보다 값 자체가 중요한 모델
- 유효성, 비교, 제약을 캡슐화함

### Use Case Boundary

- use case는 가능하면 명시적 request/response boundary로 호출합니다.
- request model은 framework event가 아니라 use case가 이해할 입력 데이터여야 합니다.
- response model은 raw DTO나 persistence model이 아니라 application boundary에서 읽을 수 있는 단순 데이터여야 합니다.
- output boundary가 있으면 안쪽 레이어가 바깥 레이어 타입 이름을 직접 알지 않도록 설계합니다.

### Repository Protocol

- 안쪽 레이어가 필요로 하는 데이터 접근 계약
- protocol 자체는 안쪽 경계, 보통 UseCase 또는 Domain이 속한 feature boundary에 둡니다
- 의미 있는 도메인 연산 단위로 설계합니다

### Repository Implementation

- `Data / Interface Adapters` 경계에서 protocol을 구현합니다
- concrete data source는 Infrastructure capability를 통해 조합합니다
- concrete wiring은 composition root가 담당합니다

### DTO / Mapper

- 외부 경계와 내부 경계 사이의 번역기
- DTO는 경계 밖 형식이고, Domain model은 안쪽 형식
- mapper는 경계에만 존재

### Boundary Data Rule

- boundary를 넘는 데이터는 해당 경계의 목적에 맞는 simple model로 유지합니다.
- raw DTO, persistence object, framework-shaped model을 안쪽 경계로 직접 넘기지 않습니다.
- domain entity를 그대로 UI에 밀어 넣지 않고, 표시용 formatting/aggregation이 생기면 presentation model로 변환합니다.
- presentation model 생성은 Presentation 또는 output boundary에서 담당합니다.

## State And Effects

### State Ownership

- Presentation이 presentation state를 소유합니다.
- Domain은 화면 상태를 몰라야 합니다.
- persistence state와 presentation state를 같은 모델로 합치지 않습니다.

### Effect Boundary

- 부수효과는 바깥 레이어에서 발생합니다.
- UseCase는 orchestration은 할 수 있지만 구현 세부 effect를 몰라야 합니다.
- retry, debounce, cancellation 같은 정책은 경계에서 의도적으로 둡니다.
- 장시간 실행되는 작업은 취소 가능성과 lifetime ownership을 명시해야 합니다.

## Navigation And Composition

### Navigation

- navigation 결정은 Presentation 계층 또는 그 보조 계층 책임입니다.
- UseCase나 Domain이 화면 이동을 알면 안 됩니다.
- 비즈니스 결과와 UI 정책은 분리합니다.

### Composition Root

- DI 조립은 앱 시작점 또는 feature composition root에서 합니다.
- 각 레이어는 “누가 나를 생성하는지”보다 “무엇에 의존하는지”만 압니다.
- concrete wiring은 가능한 한 한곳에 모읍니다.

### Feature Boundary

- 각 feature는 자신의 presentation, use case, repository contract를 소유하는 boundary를 가질 수 있습니다.
- cross-feature dependency는 app root 또는 상위 composition root에서만 연결합니다.
- feature 내부 Presentation은 concrete infra를 직접 생성하지 않습니다.

## Naming And Placement

### Naming

- 구조는 framework보다 feature와 use case를 먼저 드러내야 합니다.
- UseCase는 사용자 의도 이름
- Repository는 data source명이 아니라 도메인 의미 이름
- DTO와 Mapper는 번역 경계를 드러내는 이름

### Placement

- exact folder layout보다 책임과 import graph가 더 중요합니다.
- 다만 파일 배치를 보았을 때 framework보다 feature/use case가 먼저 보이는 방향을 선호합니다.

## Invariant Enforcement Model

이 starter에서 architecture invariant의 canonical owner는 이 문서입니다.
기계적으로 검증 가능한 subset은 아래 아티팩트가 집행합니다.

- [`.architecture-invariants.toml`](../.architecture-invariants.toml)
- [`scripts/check-architecture-invariants.py`](../scripts/check-architecture-invariants.py)
- `make verify-architecture`
- `.github/workflows/architecture-invariants.yml`

이 구조의 목적은 “모든 설계 판단을 lint로 대체”하는 것이 아닙니다.
대신 high-confidence rule만 자동화하고, 의미 판단이 필요한 경계는 리뷰와 계획 문서가 맡습니다.

### Machine-Checkable Subset

v1에서 기계적으로 강제하는 대상은 아래입니다.

- path 기반 layer ownership
- obvious misplaced file 규칙
- layer별 forbidden import
- 위험한 content rule의 제한된 subset
- generated zone skip
- test zone relaxed policy
- 만료된 exemption 검출

기본 예시는 아래 같은 규칙을 다룹니다.

- `Domain`이 UI/persistence/network framework를 import하지 않음
- `UseCase/Service`가 concrete DB/network framework를 import하지 않음
- `ViewController`, `ViewModel`, `Presenter`가 `ui` layer에만 위치
- `DTO`, `Mapper`가 `repo` layer에만 위치
- `AppDelegate`, `SceneDelegate`가 `runtime` layer에만 위치
- `Task.detached`는 exemption 없이 사용하지 않음

### Human-Review-Only Subset

아래는 lint만으로 안전하게 판정하지 않습니다.

- use case 경계가 정말 의미 있는지
- repository/service 분리가 과한지 부족한지
- cross-feature coupling이 제품 요구에 비해 적절한지
- output boundary와 presentation model 번역 위치가 자연스러운지
- layer 이름은 맞지만 실제 책임이 새고 있지는 않은지

이 영역은 `QUALITY_SCORE.md`, active execution plan, 코드 리뷰가 함께 판단합니다.

### Exemption Policy

예외는 금지하지 않지만, 반드시 time-boxed debt로 취급합니다.
`.architecture-invariants.toml`의 exemption은 아래 정보를 가져야 합니다.

- `reason`
- `owner`
- `ticket`
- `expires_on`

원칙은 아래와 같습니다.

- blanket ignore를 두지 않습니다.
- 만료된 exemption은 lint failure입니다.
- exemption을 추가하거나 변경하면 `plan-required` 변경으로 다룹니다.
- legacy bridge는 언제 제거할지 조건을 남깁니다.

### Rollout Guidance

새 프로젝트는 아래 순서로 도입하는 것을 권장합니다.

1. path ownership과 zone mapping부터 맞춥니다.
2. unknown path와 forbidden import를 `warn` 또는 제한된 `error`로 시작합니다.
3. 반복 위반이 많은 high-confidence rule만 `error`로 승격합니다.
4. 새로운 suppression 대신 만료일 있는 exemption을 사용합니다.
5. 경고가 반복되면 구조 문서나 active plan으로 승격합니다.

## Testing Strategy

### Presentation Tests

- state transformation
- user intent handling
- loading/error/empty/success transition

### UseCase Tests

- repository/gateway/output boundary를 통한 정책 테스트
- 성공/실패 조합
- 응용 흐름의 경계 조건

### Domain Tests

- entity/value object/domain rule 테스트
- 상태 전이와 invariant 검증
- 가장 빠르고 싸게 돌 수 있어야 함

### Adapter / Infrastructure Tests

- mapping correctness
- repository implementation behavior
- 외부 경계와의 통합 성격 검증

### Boundary Contract Tests

- boundary model 번역과 실패 semantics를 검증합니다.
- architecturally significant boundary의 성공/실패/취소 계약을 검증합니다.

### Testing Boundary Rule

- mock/fake는 architecturally significant boundary에서만 사용합니다.
- Domain 테스트는 가능하면 real entity와 value object를 사용하고 내부 협력자 mocking에 의존하지 않습니다.
- UseCase 테스트는 repository/gateway/output boundary 같은 실제 경계 contract에서만 test double을 씁니다.

## Anti-Patterns

- framework-shaped model이 안쪽 경계로 새는 것
- 의미 없는 protocol 남발
- 버튼 하나당 기계적으로 use case를 나누는 것
- UseCase 안에 navigation이나 formatting을 넣는 것
- God Repository / God UseCase
- 구조가 feature보다 framework를 먼저 드러내는 것

## Exceptions And Legacy

- 이 문서는 새 코드의 목표 상태를 정의합니다.
- 기존 구조가 항상 이 규칙을 만족한다고 가정하지 않습니다.
- legacy 예외는 현재 상태, 목표 상태, 남아 있는 이유, 정리 조건을 남깁니다.
- touched legacy는 새 규칙에 맞게 이동할 기회를 우선 검토합니다.

## Adoption Rules

- 새 module/feature는 기본적으로 이 문서를 따릅니다.
- platform-specific rule은 이 문서 위에 별도 보조 문서로 추가합니다.
- `plan-required` 리팩터링과 migration은 active execution plan 없이 진행하지 않습니다.
- invariant rule을 바꾸거나 exemption을 추가할 때도 active execution plan을 우선 검토합니다.

## Decision Checklist

- 이 로직은 어느 레이어 책임인가
- 의존성이 바깥에서 안쪽으로만 향하는가
- framework/DTO/persistence model이 안쪽으로 새지 않았는가
- use case input/output boundary가 분명한가
- presentation model 변환 위치가 명확한가
- 테스트 seam이 실제 경계와 맞는가

## Relation To The Repo Architecture Map

- `ARCHITECTURE.md`는 저장소 구조와 문서 라우팅을 설명합니다.
- 이 문서는 플랫폼 공통의 Clean Architecture 운영 규칙을 설명합니다.
- 플랫폼 전용 제약은 해당 플랫폼 문서가 보조합니다.
