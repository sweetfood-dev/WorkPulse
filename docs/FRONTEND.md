# FRONTEND.md

## Purpose

이 문서는 프론트엔드 구현에서 공통으로 지켜야 할 기준을 정의합니다.

## Core Rules

- 데이터 획득, 상태 조합, 렌더링 책임을 가능하면 분리한다
- 서버 상태, 클라이언트 상태, 임시 UI 상태를 섞지 않는다
- 접근성과 실패 상태를 정상 흐름만큼 의도적으로 다룬다
- 재사용은 시각적 공용화보다 행동과 경계의 일관성을 우선한다

## Related Architecture Docs

- 공통 구조 규칙은 [`clean-architecture.md`](./clean-architecture.md)를 기준으로 봅니다.
- iOS/Swift 보조 규칙은 [`ios-architecture.md`](./ios-architecture.md)를 기준으로 봅니다.
- 플랫폼별 세부 구조 규칙은 이 문서가 아니라 해당 아키텍처 문서가 소유합니다.
