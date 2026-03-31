# PLANS.md

## Purpose

이 문서는 실행 계획을 어떻게 만들고 유지할지 정의합니다.
계획 문서는 장식이 아니라 중간 이상 크기의 변경을 추적 가능한 작업 단위로 바꾸기 위한 운영 아티팩트입니다.

## Where Plans Live

- 진행 중 계획: `docs/exec-plans/active/`
- 완료된 계획: `docs/exec-plans/completed/`
- 아직 승격되지 않은 부채: `docs/exec-plans/tech-debt-tracker.md`

## Plan-Required Threshold

아래 중 하나에 해당하면 active plan을 먼저 만듭니다.

- 변경이 3개 이상 파일에 걸치고, 단순 문구 수정이 아니라 동작/규칙/구조를 바꾼다
- 두 개 이상 레이어, 모듈, 문서 카테고리를 함께 조정한다
- 리팩터링, 마이그레이션, staged rollout처럼 순서가 중요한 작업이다
- 행동 변경과 구조 변경을 동시에 조율해야 한다
- 이후 작업들이 참조할 durable rule이나 architecture guidance를 바꾼다
- reviewer가 명시적 순서나 verification step 없이 안전하게 판단하기 어렵다

헷갈리면 plan을 만드는 쪽으로 결정합니다.

## Usually Not Plan-Required

아래 작업은 보통 active plan 없이 처리해도 됩니다.

- 단일 파일의 오타, 링크, 문장 다듬기
- 동작 변화가 없는 국소적 리팩터링
- 기존 규칙을 바꾸지 않는 소규모 보강
- 이미 열려 있는 active plan에 속한 작은 후속 수정

## Minimum Contents

계획 문서는 가능하면 아래를 포함합니다.

- 상태
- owner
- 변경 요약
- 목표와 범위
- 비목표
- 제약 조건
- 관련 spec / design doc / debt item
- 테스트 시나리오
- 명시적 가정
- 진행 상태

## Execution State

실행 상태는 active execution plan에만 기록합니다.
product spec은 행동과 성공 기준을 설명할 수 있지만, 구현 단계 체크리스트를 소유하지 않습니다.

active execution plan에서 쓰는 기본 체크리스트 상태는 아래와 같습니다.

- `[ ]`: 아직 시작하지 않음
- `[-]`: 진행 중, 현재 slice의 다음 행동이 남아 있음
- `[x]`: 검증된 완료 상태

기본 전이 규칙은 아래와 같습니다.

- 새 item은 `[ ]`로 시작
- `Red`만 끝났다면 `[ ] -> [-]`
- 검증된 `Green`까지 끝났다면 `[-] -> [x]`
- 기존 동작 보존용 characterization slice가 즉시 끝나고 추가 구현이 없다면 `[ ] -> [x]`
- `[-]` item이 있으면 새 `[ ]` item보다 먼저 재개

interactive TDD protocol이 필요하면 `docs/TDD.md`를 따릅니다.

## Naming And Linking

- 파일명은 가능하면 `YYYY-MM-DD-short-slug.md`
- active plan은 관련 spec, design doc, debt item을 링크합니다
- 완료 후 `completed/`로 옮길 때 결과와 남은 리스크를 남깁니다

## Lifecycle

1. 작업 시작 전에 `active/`에 생성
2. 진행 중 계속 갱신
3. 완료 후 `completed/`로 이동

## Review Contract

plan-required 변경은 최소한 아래 질문에 답할 수 있어야 합니다.

- 왜 plan이 필요한가
- 어떤 순서로 진행하는가
- 어디서 멈추고 검증하는가
- 어떤 테스트 또는 확인으로 완료를 판단하는가
- 어떤 문서가 함께 갱신되어야 하는가

## Relation To Other Docs

- 제품 스펙은 `무엇을 왜 만들지`
- 계획 문서는 `어떻게 순서 있게 진행할지`
- 디자인 문서는 `왜 이런 상호작용과 구조를 택했는지`
