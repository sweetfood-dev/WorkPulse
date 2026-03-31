# SECURITY.md

## Purpose

이 문서는 보안 판단의 기본 자세와 escalation 조건을 정의합니다.

## Default Posture

- 최소 권한을 기본값으로 둔다
- 민감 정보는 문서, 코드, 예시에 넣지 않는다
- destructive action과 권한 변화는 별도 검토 대상으로 본다
- 불확실하면 허용보다 보류를 기본값으로 둔다

## Required Evidence

- 어떤 데이터나 권한이 새로 다뤄지는지 설명할 수 있다
- 최소 권한보다 더 넓은 접근이 필요하면 이유가 적혀 있다
- destructive action이면 복구 또는 롤백 경로가 있다
- 외부 통합이면 비밀정보 저장/전송 경계가 설명된다

## Immediate Escalation

- 개인정보 노출 가능성
- 결제, 정산, 권한 상승 관련 변경
- 데이터 손실 가능성이 있는 변경
- 문서와 실제 보안 동작이 충돌하는 상황

## Security Review Triggers

- 인증/권한 흐름 변경
- 외부 통합 추가
- 사용자 데이터 저장/전송 방식 변경
- irreversible migration 또는 destructive admin action 도입

## Blocking Questions

- 이 변경이 더 넓은 권한을 요구하는가
- 민감 정보가 새 경로로 이동하거나 노출될 가능성이 있는가
- 되돌릴 수 없는 동작에 대한 보호장치가 있는가
- 문서의 설명과 실제 보안 동작이 어긋나지 않는가
