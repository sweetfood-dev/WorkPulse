# BOOTSTRAP.md

## Purpose

이 문서는 이 저장소를 새 프로젝트의 starter repo로 사용할 때 무엇을 먼저 바꿔야 하는지 설명합니다.
또한 이 starter의 baseline contract를 정의하는 canonical owner입니다.

## Contract Ownership

- 이 문서가 무엇을 기본으로 유지하고 무엇을 제거할 수 있는지 정의합니다.
- `README.md`는 이 문서를 가리키는 짧은 entrypoint입니다.
- `ARCHITECTURE.md`는 현재 저장소 구조와 라우팅을 설명합니다.
- `scripts/check-required-docs.sh`는 여기서 정의된 baseline 중 기계적으로 검증 가능한 subset만 검사합니다.

## First Pass

새 프로젝트를 시작하면 먼저 아래를 수행합니다.

- `README.md`의 프로젝트 설명을 실제 프로젝트 이름과 목적에 맞게 수정
- `ARCHITECTURE.md`의 `What This Repo Is`, core/optional 문서 목록, specialized doc 목록을 실제 구조에 맞게 수정
- core 문서(`GOLDEN_PRINCIPLES`, `ENGINEERING_RULES`, `TDD`, `PLANS`, `PRODUCT_SENSE`, `QUALITY_SCORE`, `DESIGN`)를 실제 팀 작업 방식에 맞게 검토
- optional specialized doc 중 현재 프로젝트에 맞지 않는 문서는 제거
- 필요한 specialized doc만 유지 또는 추가
- `docs/clean-architecture.md`를 유지한다면 `.architecture-invariants.toml`, `scripts/check-architecture-invariants.py`, 관련 workflow도 함께 맞춤화
- starter baseline에는 `docs/GOLDEN_PRINCIPLES.md`와 관련 registry/scripts/workflow가 포함됩니다.
- 유지한다면 `.golden-principles.toml`, `scripts/check-golden-principles.py`, `scripts/run-garbage-collection.py`, `scripts/classify-gc-actions.py`, `scripts/apply-safe-cleanups.py`, 관련 workflow와 subagent도 함께 맞춤화
- 제거하거나 다른 health system으로 교체하려면 관련 registry/scripts/workflow/subagent를 같은 변경에서 함께 제거
- 스택별 산출물에 맞게 `.gitignore` 확장

## Core Starter Contract

이 starter에서 기본적으로 유지하는 core 문서는 아래입니다.

- `AGENTS.md`의 짧은 지도 역할
- `docs/GOLDEN_PRINCIPLES.md`
- `docs/ENGINEERING_RULES.md`
- `docs/TDD.md`
- `docs/PLANS.md`
- `docs/PRODUCT_SENSE.md`
- `docs/QUALITY_SCORE.md`
- `docs/DESIGN.md`
- `.codex/agents/`의 역할 기반 서브에이전트 개념

## Optional Specialized Docs

아래 문서는 starter에 포함되지만, 프로젝트에 맞지 않으면 제거할 수 있습니다.

- `docs/RELIABILITY.md`
- `docs/SECURITY.md`
- `docs/FRONTEND.md`
- `docs/clean-architecture.md`
- `docs/ios-architecture.md`
- `docs/MCP_TOOLING.md`

optional 문서를 제거할 때는:

- `ARCHITECTURE.md`의 specialized doc 목록을 같이 갱신
- 프로젝트별 onboarding 문서에서 해당 링크 제거
- `make verify`가 요구하는 core 계약은 유지

`docs/clean-architecture.md`를 유지할 때는:

- `.architecture-invariants.toml`을 실제 프로젝트 경로와 레이어 이름에 맞게 수정
- `scripts/check-architecture-invariants.py`를 그대로 쓰거나 프로젝트 언어에 맞게 교체
- `scripts/test-architecture-linter.sh`와 `.github/workflows/architecture-invariants.yml`를 유지 또는 프로젝트 규칙에 맞게 갱신
- `make verify-architecture`가 실제 제품 코드에 대해 의미 있게 동작하는지 확인

`docs/clean-architecture.md`를 제거할 때는:

- `.architecture-invariants.toml`
- `scripts/check-architecture-invariants.py`
- `scripts/test-architecture-linter.sh`
- `.github/workflows/architecture-invariants.yml`

도 함께 제거하거나 다른 architecture profile로 교체합니다.

starter baseline의 `docs/GOLDEN_PRINCIPLES.md`를 유지할 때는:

- `.golden-principles.toml`의 owner path, stale threshold, GC 출력 경로를 실제 프로젝트에 맞게 수정
- `.golden-principles.toml`의 auto-fix allowlist, blocked path, batch limit도 실제 프로젝트 위험도에 맞게 조정
- `scripts/check-golden-principles.py`가 현재 문서 owner를 올바르게 가리키는지 확인
- `scripts/run-garbage-collection.py`의 scan scope와 stale threshold를 실제 프로젝트에 맞게 조정
- `scripts/classify-gc-actions.py`가 repo의 cleanup policy와 triage 기준을 올바르게 반영하는지 확인
- `scripts/apply-safe-cleanups.py`가 generated artifact 외의 파일을 건드리지 않도록 검토
- `.github/workflows/golden-principles.yml`과 `.github/workflows/monthly-garbage-collection.yml`를 유지 또는 팀 cadence에 맞게 갱신
- `.codex/agents/gc-curator.toml`가 현재 프로젝트의 cleanup 기준을 반영하는지 확인
- `.codex/agents/cleanup-patcher.toml`가 현재 프로젝트의 safe cleanup allowlist를 반영하는지 확인

starter baseline의 `docs/GOLDEN_PRINCIPLES.md`를 제거하거나 교체할 때는:

- `.golden-principles.toml`
- `scripts/check-golden-principles.py`
- `scripts/run-garbage-collection.py`
- `scripts/classify-gc-actions.py`
- `scripts/apply-safe-cleanups.py`
- `scripts/test-golden-principles.sh`
- `.github/workflows/golden-principles.yml`
- `.github/workflows/monthly-garbage-collection.yml`
- `.codex/agents/gc-curator.toml`
- `.codex/agents/cleanup-patcher.toml`

도 함께 제거하거나 다른 repo health system으로 교체합니다.

## First Project Documents

프로젝트를 실제로 시작할 때는 가능하면 아래를 만듭니다.

- 첫 product spec: `docs/product-specs/`
- 첫 design doc: `docs/design-docs/`
- 첫 active execution plan: `docs/exec-plans/active/`

`plan-required` 변경이면 구현 전에 active plan부터 엽니다.
`docs/exec-plans/completed/`는 비워진 상태로 시작하고, 첫 완료 이력은 새 프로젝트 작업부터 쌓습니다.
`docs/exec-plans/tech-debt-tracker.md`도 실제 프로젝트 부채가 생길 때부터 채웁니다.

## Template Hygiene

- 템플릿에서 가져온 문서가 실제 프로젝트 구조와 어긋나면 바로 수정합니다.
- 사용하지 않는 optional specialized doc은 남겨 두지 않습니다.
- 새로 생긴 durable rule은 루트 운영 문서나 specialized doc으로 승격합니다.
- 템플릿 제작 과정의 completed plan이나 debt item을 프로젝트 이력처럼 남겨 두지 않습니다.

## Verification

기본 검증은 아래 명령으로 실행합니다.

```sh
make verify
```

이 검증은 starter repo 수준의 문서 무결성만 다룹니다.
실제 제품 코드 검증은 프로젝트별 CI에 추가해야 합니다.

`docs/clean-architecture.md`를 유지하는 프로젝트라면 추가로 아래를 맞춤화합니다.

```sh
make verify-architecture
make test-architecture-linter
make verify-all
```

starter baseline의 `docs/GOLDEN_PRINCIPLES.md`를 유지하는 프로젝트라면 아래도 함께 사용합니다.

```sh
make verify-golden-principles
make test-golden-principles
make garbage-collect
make classify-gc-actions
make apply-safe-cleanups
```
