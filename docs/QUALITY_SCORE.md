# QUALITY_SCORE.md

## Purpose

이 문서는 결과물을 어떤 기준으로 좋은 변경이라고 볼지 정의합니다.

## Dimensions

- Correctness
- Clarity
- Product Fit
- Operability
- Evolvability

## Minimum Bar

좋은 변경은 아래를 만족해야 합니다.

- 동작이 맞다
- 의도와 구조가 읽힌다
- 사용자 문제와 연결된다
- 실패 경로를 다룬다
- 다음 변경을 더 어렵게 만들지 않는다

## Review Contract

리뷰에서는 최소한 아래 질문을 통해 각 차원을 확인합니다.

- Correctness: 동작이 맞다는 근거가 테스트, 시나리오, 계약 중 무엇으로 제시되는가
- Clarity: 책임과 경계가 문서와 구현에서 같은 방식으로 읽히는가
- Product Fit: 사용자 문제와 성공 기준이 여전히 연결되는가
- Operability: 실패 상태, 관찰 가능성, 회복 경로가 설명되는가
- Evolvability: 이번 구조가 다음 변경 비용을 낮추는가, 아니면 올리는가
- Golden Principles: repo-level golden principle 위반이나 exemption이 있다면 severity와 next action이 설명되는가

프로젝트가 machine-checkable architecture invariant를 유지한다면 아래도 확인합니다.

- 선언된 layer ownership과 forbidden dependency 규칙을 지켰는가
- 예외가 있다면 reason, owner, ticket, expires_on이 남아 있는가
- 새 exemption이나 invariant 변경이 `plan-required`로 다뤄졌는가

어느 한 차원이라도 약하면 이유와 보완 계획이 설명돼야 합니다.

## How To Use

- 계획 리뷰에서 리스크를 찾는다
- 구현 후 어떤 차원이 약한지 설명한다
- 반복적으로 약한 차원은 운영 규칙으로 승격한다
