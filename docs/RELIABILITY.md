# RELIABILITY.md

## Purpose

이 문서는 시스템 신뢰성을 어떤 관점으로 다룰지 정의합니다.

## Scope Boundary

이 문서는 현재 저장소의 `문서/운영 신뢰성`을 다룹니다.
런타임 SLO, 장애 대응, 서비스 가용성 같은 제품별 runtime reliability는 해당 시스템 문서에서 따로 다룹니다.

## Reliability Means

이 저장소에서 신뢰성은 아래를 뜻합니다.

- 같은 작업이 같은 진입 경로를 가진다
- 현재 진행 중인 계획과 기준 문서를 다시 찾을 수 있다
- 문서와 실제 구조가 서로 다른 진실을 말하지 않는다
- 큰 변경이 추적 가능한 상태로 남는다

## Review Triggers

- `plan-required` 변경을 active plan 없이 진행하려 할 때
- 같은 판단 기준이 여러 문서에 중복될 때
- generated와 handwritten 경계가 흐려질 때
- 반복 피드백이 문서로 승격되지 않을 때

## Review Questions

- 지금 변경의 최신 진실이 어디 있는지 바로 가리킬 수 있는가
- 같은 규칙이 둘 이상의 문서에서 서로 다르게 말하지 않는가
- plan-required 변경이라면 active plan이 실제로 열려 있는가
- 이번 작업에서 생긴 durable rule을 문서로 승격해야 하지 않는가
- monthly garbage collection이 남긴 debt, stale plan, expired exemption이 방치되고 있지 않은가

위 질문 중 하나라도 아니면 문서 정리나 plan 정렬이 먼저입니다.

## Recovery Principle

문서 체계가 흔들리면 먼저 새 진실의 위치를 만들고, 그 다음에 오래된 경로를 정리합니다.
