# ARCHITECTURE.md

## Purpose

이 문서는 이 저장소의 현재 구조와 문서 역할 분리를 설명하는 최상위 맵입니다.
코드 아키텍처 규칙 자체를 모두 담는 문서가 아니라, 어떤 종류의 지식이 어디에 있어야 하는지 설명하는 저장소 수준의 구조 문서입니다.

## What This Repo Is

이 저장소는 WorkPulse를 위한 제품 저장소입니다.
현재는 문서, 규칙, 검증 도구를 먼저 정리한 상태이며, macOS 메뉴바 근태 앱 구현이 이어질 기준점을 담습니다.

핵심 원칙은 아래와 같습니다.

- `AGENTS.md`는 짧은 진입 지도만 담당합니다.
- 저장소 구조와 문서 라우팅은 이 문서가 설명합니다.
- 반복되는 운영 기준은 `docs/*.md`에 둡니다.
- 실행 계획, 제품 스펙, 디자인 근거, generated, references는 역할별로 분리합니다.
- 플랫폼 전용 구현 규칙은 `docs/macos-architecture.md`가 설명합니다.

## Top-Level Layout

| 경로 | 역할 |
| --- | --- |
| `README.md` | 사람 기준의 WorkPulse 저장소 진입점 |
| `AGENTS.md` | 읽기 순서를 알려주는 최상위 지도 |
| `ARCHITECTURE.md` | 저장소 구조와 문서 라우팅을 설명하는 최상위 맵 |
| `.architecture-invariants.toml` | machine-checkable architecture invariant 설정 |
| `.golden-principles.toml` | golden principles registry와 monthly GC 설정 |
| `.codex/agents/` | 프로젝트 전용 custom subagent 정의 |
| `.codex/config.toml` | 프로젝트 전용 subagent 설정 |
| `scripts/` | 로컬 문서 검증, invariant, golden principles, garbage collection 보조 스크립트 |
| `.github/workflows/` | starter 수준의 CI 검증과 optional invariant / GC workflow |
| `docs/` | 실제 운영 문서의 시스템 오브 레코드 |

## Root Operating Docs In This Repo

| 경로 | 역할 |
| --- | --- |
| `docs/GOLDEN_PRINCIPLES.md` | repo-level golden principles index와 GC routing |
| `docs/ENGINEERING_RULES.md` | 기본 작업 방식과 변경 원칙 |
| `docs/TDD.md` | 테스트 우선 개발과 검증 루프 |
| `docs/PLANS.md` | 실행 계획 시스템 규칙 |
| `docs/PRODUCT_SENSE.md` | 제품 판단 기준 |
| `docs/QUALITY_SCORE.md` | 품질 판단 기준 |
| `docs/DESIGN.md` | 디자인 판단 기준 |
| `docs/design-docs/` | 장기적으로 유지할 디자인 판단 근거 |
| `docs/exec-plans/` | active/completed 계획과 기술 부채 추적 |
| `docs/product-specs/` | 제품 요구사항과 스펙 |

## Specialized Docs Included In This Starter

이 문서가 설명하는 것은 현재 WorkPulse에서 유지하는 specialized doc의 구조입니다.

| 경로 | 역할 |
| --- | --- |
| `docs/RELIABILITY.md` | 신뢰성 운영 기준 |
| `docs/SECURITY.md` | 보안 운영 기준 |
| `docs/FRONTEND.md` | 프론트엔드 구현 기준 |
| `docs/clean-architecture.md` | 플랫폼 공통 Clean Architecture 규칙 |
| `docs/macos-architecture.md` | macOS 전용 애플리케이션 아키텍처 규칙 |
| `docs/MCP_TOOLING.md` | Codex/MCP 기반 도구 선택 휴리스틱 |

## Supporting Directories

| 경로 | 역할 |
| --- | --- |
| `docs/generated/` | generated 문서 |
| `docs/references/` | 외부 참조 자료 |

## Reading Order

작업을 시작할 때는 아래 순서를 기본값으로 둡니다.

1. `AGENTS.md`
2. `ARCHITECTURE.md`
3. 작업에 필요한 루트 운영 문서
4. 필요하면 specialized doc
5. 구체 문서가 있으면 해당 하위 디렉터리 문서

권장 읽기 분기는 아래와 같습니다.

- 기본 작업 방식이 필요하면 `docs/ENGINEERING_RULES.md`
- TDD나 검증 루프가 필요하면 `docs/TDD.md`
- 실행 흐름이 필요하면 `docs/PLANS.md`
- repo-level golden principles나 monthly cleanup 흐름이 필요하면 `docs/GOLDEN_PRINCIPLES.md`
- 제품 판단이 애매하면 `docs/PRODUCT_SENSE.md`
- 품질 기준이 필요하면 `docs/QUALITY_SCORE.md`
- 디자인 판단이 필요하면 `docs/DESIGN.md`
- 신뢰성/보안 판단이 필요하고 해당 specialized doc이 있으면 각각 해당 문서
- 구조 규칙이 필요하고 해당 specialized doc이 있으면 `docs/clean-architecture.md`
- UI/프론트엔드 작업이고 해당 specialized doc이 있으면 `docs/FRONTEND.md`
- macOS 런타임, AppKit, 메뉴바 앱 규칙이 필요하면 `docs/macos-architecture.md`
- Codex/MCP 도구 휴리스틱이 필요하고 해당 specialized doc이 있으면 `docs/MCP_TOOLING.md`
- 개별 기능의 디자인 근거가 필요하면 `docs/design-docs/`
- 구체 기능 요구가 필요하면 `docs/product-specs/`

## Routing Rules

문서를 어디에 둘지 정하는 기본 규칙은 아래와 같습니다.

- 실행 순서와 진행 상태: `docs/exec-plans/`
- 제품 요구와 성공 기준: `docs/product-specs/`
- 디자인 판단 근거: `docs/design-docs/`
- 반복되는 공통 운영 기준: `docs/*.md`
- 생성된 파생 문서: `docs/generated/`
- 외부 자료와 참조물: `docs/references/`

## Relation To Specialized Docs

- 이 문서는 저장소 전체 구조를 설명합니다.
- specialized architecture rule은 공통 문서와 플랫폼 문서로 나눠 둘 수 있습니다.
- tool-specific policy는 specialized tooling 문서로 분리할 수 있습니다.
- `docs/clean-architecture.md`를 유지한다면 machine-checkable subset은 `.architecture-invariants.toml`과 `scripts/check-architecture-invariants.py`가 집행합니다.
- `docs/GOLDEN_PRINCIPLES.md`를 유지한다면 registry와 garbage collection loop는 `.golden-principles.toml`, `scripts/check-golden-principles.py`, `scripts/run-garbage-collection.py`가 집행합니다.

즉:

- `ARCHITECTURE.md` = 저장소 구조의 현실 지도
- `docs/*.md`의 core 문서 = 반복되는 기본 운영 기준
- specialized doc = 프로젝트가 필요할 때 유지하는 추가 규칙서

## Invariants

- `AGENTS.md`는 짧게 유지합니다.
- 저장소 라우팅과 책임 분리는 이 문서가 설명합니다.
- specialized doc은 유지한다면 정확한 프로젝트 기준으로 갱신해야 합니다.
- 루트 운영 문서는 반복 기준만 담고, 개별 기능 문서는 하위 디렉터리에서 관리합니다.
- generated 문서는 handwritten 문서처럼 다루지 않습니다.
- `plan-required` 변경은 active execution plan 없이 바로 구현하지 않습니다.
- 무엇이 `plan-required`인지의 기준은 `docs/PLANS.md`가 정의합니다.
- architecture invariant와 exemption policy의 canonical owner는 `docs/clean-architecture.md`입니다.
- repo-level golden principle과 monthly garbage collection routing의 canonical owner는 `docs/GOLDEN_PRINCIPLES.md`입니다.
