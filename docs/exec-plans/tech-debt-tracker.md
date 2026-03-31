# tech-debt-tracker.md

## Purpose

이 문서는 즉시 active plan으로 승격되지는 않지만 추적해야 하는 기술 부채를 기록합니다.

## Fields

각 항목은 가능하면 아래를 가집니다.

- ID
- principle_id
- 제목
- owner
- 카테고리
- 영향
- 위험
- 승격 조건
- 마지막 검토일
- 다음 검토 시점
- 상태
- source report / source plan

상태가 바뀌거나 승격이 보류되면 한 줄 decision note를 남깁니다.

## When Debt Must Become An Active Plan

- 현재 작업을 반복적으로 방해할 때
- 신뢰성이나 보안 리스크로 이어질 때
- 여러 계획에서 동일 원인으로 재등장할 때
- 방치 비용이 계속 커질 때

## Initial Tracker

starter template는 이 문서를 빈 상태로 시작합니다.
아래 표는 프로젝트별 부채가 생겼을 때 채우는 형식입니다.

| ID | principle_id | 제목 | owner | 카테고리 | 영향 | 위험 | 승격 조건 | 마지막 검토일 | 다음 검토 시점 | 상태 | source report / source plan |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| _empty_ | _GP-XX_ | _프로젝트별 항목 추가_ | _unassigned_ | _category_ | _impact_ | _risk_ | _promotion trigger_ | _YYYY-MM-DD_ | _review point_ | _backlog_ | _generated report or active plan_ |

## Decision Notes

- starter template는 decision note 없이 시작합니다.
