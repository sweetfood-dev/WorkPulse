# GOLDEN_PRINCIPLES.md

## Purpose

이 문서는 repo-level golden principle의 index입니다.
상세 규칙은 각 canonical owner 문서가 소유하고, 이 문서는 principle ID, owner, severity floor, garbage collection routing만 정의합니다.

## How To Read This Doc

- detailed rule: 각 owner 문서
- machine-checkable subset: `.golden-principles.toml`, `.architecture-invariants.toml`, 관련 scanner
- monthly cleanup routing: `scripts/run-garbage-collection.py`, `scripts/classify-gc-actions.py`, `scripts/apply-safe-cleanups.py`
- lightweight automated scan은 stale plan/debt/doc/generated drift를 먼저 다룹니다.
- dead code, unused dependency, broader slop review는 monthly follow-up Codex task prompt가 확장해서 다룹니다.

## Principle Set

| ID | Principle | Owner | Machine-Checkable | Severity Floor | Exemption |
| --- | --- | --- | --- | --- | --- |
| `GP-01` | User Value First | `docs/PRODUCT_SENSE.md` | partial | `major` | no |
| `GP-02` | Durable Truth Has One Home | `ARCHITECTURE.md`, `docs/RELIABILITY.md` | partial | `major` | yes |
| `GP-03` | Plan Coordinated Change | `docs/PLANS.md` | partial | `major` | yes |
| `GP-04` | Evidence Before Confidence | `docs/TDD.md`, `docs/QUALITY_SCORE.md` | partial | `major` | yes |
| `GP-05` | Boundaries Are Real | `docs/clean-architecture.md`, `.architecture-invariants.toml` | strong | `blocker` | yes |
| `GP-06` | Safe By Default, Reversible When Risky | `docs/SECURITY.md`, `docs/RELIABILITY.md`, `docs/DESIGN.md` | partial | `blocker` | limited |

## Severity Model

- `blocker`
  - merge 불가
  - correctness break, declared invariant break, destructive change without recovery, security/privacy breach
- `major`
  - time-boxed exemption 없으면 merge 불가
  - `plan-required` 변경인데 plan 없음, verification evidence 부족, 중요한 boundary leak
- `minor`
  - merge 가능, follow-up 필요
  - stale doc routing, overdue debt review, low-risk cleanup 누락
- `advisory`
  - 개선 제안 수준

## Exemption Policy

- `blocker`는 기본적으로 exemption 대상이 아닙니다.
- `major`와 일부 `minor`만 time-boxed exemption을 허용합니다.
- exemption은 반드시 아래를 가집니다.
  - `principle_id`
  - `scope`
  - `reason`
  - `mitigation`
  - `owner`
  - `ticket`
  - `expires_on`
  - `linked debt item or active plan`
- 만료일 없는 exemption은 금지합니다.
- exemption 추가/연장은 보통 `plan-required`입니다.

## Garbage Collection Loop

repo entropy는 PR-time blocking check만으로는 충분히 줄어들지 않습니다.
이 starter는 월간 garbage collection loop를 별도 경로로 둡니다.

기본 루프:

1. `make garbage-collect`
2. `make classify-gc-actions`
3. allowlist 안의 trivial finding만 `make apply-safe-cleanups`
4. generated report, action classification, 필요시 active cleanup plan 생성
5. 결과를 아래 셋 중 하나로 보냄

- `cleanup-pr`
  - 작은 mechanical cleanup
  - high-confidence
  - behavior change 없음
- `debt`
  - 지금 바로 고치기엔 맥락이 부족하거나 confidence가 낮음
- `active-plan`
  - 순서 있는 cleanup, migration, 여러 파일/레이어 정리가 필요

## Auto-Fix Guardrails

- auto-fix는 `minor` 또는 `advisory` finding만 대상으로 합니다.
- confidence가 `high`이고 recommended next action이 `cleanup-pr`일 때만 auto-fix 후보가 됩니다.
- owner policy 문서, machine config, workflow policy 파일은 auto-fix 대상에서 제외합니다.
- starter의 기본 allowlist는 `docs/generated/garbage-collection/` 아래 generated artifact만 포함합니다.
- allowlist 밖의 finding은 cleanup 가치가 있어도 `debt` 또는 `active-plan`으로 남깁니다.
- monthly cleanup PR은 항상 draft로 열고, safe allowlist 밖의 변경은 포함하지 않습니다.

## Monthly Starting Prompt

월 1회 background Codex task의 시작점은 아래 prompt를 기본으로 둡니다.
자동 scanner가 직접 찾지 않는 dead code, unused dependency, broader drift는 이 follow-up task가 담당합니다.

```text
Review this repository for garbage collection and golden-principles drift.

Report only:
1. files that are no longer referenced by build graph, source, docs, scripts, or config
2. dead code candidates with supporting evidence
3. unused dependencies with supporting evidence
4. expired exemptions
5. stale active plans or debt items
6. duplicate or conflicting source-of-truth docs
7. repeated Minor/Major violations grouped by principle

For each finding, include:
- severity
- principle_id
- file or doc reference
- why it matters
- confidence
- recommended next action: cleanup-pr, debt, or active-plan

Be conservative.
Do not propose broad rewrites unless duplication or drift is already causing review noise.
```

## Workflow Expectations

- 작은 PR은 principle checklist를 길게 반복하지 않습니다.
- `plan-required` 변경은 relevant principle과 evidence를 설명해야 합니다.
- monthly GC는 blocking CI가 아니라 별도 cadence의 maintenance loop입니다.
- repeated minor drift는 debt로 승격하고, repeated major drift는 active plan으로 승격합니다.
- monthly GC workflow가 여는 PR은 report + allowlisted safe cleanup만 담는 draft PR이어야 합니다.
