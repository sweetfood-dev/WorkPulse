# main-popover-refactor-boundaries.md

## 문제와 맥락

현재 메인 popover는 기능적으로는 동작하지만, 편집/저장/현재 세션 갱신/UI 전환이 컨트롤러에 함께 모여 있다.
이 상태는 작은 기능에는 충분하지만, 시간 검증 규칙이나 추가 편집 정책이 생기면 변경 surface가 빠르게 커진다.

## 목표

- 데이터 무결성 규칙을 저장 직전 경계에서 강제한다
- stale displayed reference date가 저장 대상 날짜를 잘못 고정하지 않도록 한다
- 편집 UI의 임시 상태와 AppKit control 상태를 분리한다
- runtime isolation 계약을 명시해 테스트/프로덕션 경계를 더 안전하게 만든다

## 비목표

- 새로운 도메인 레이어를 크게 도입하는 것
- 단일 사용처를 위한 과한 추상화 추가
- 현재 popover를 완전히 다른 구성으로 재작성하는 것

## 대안 비교

### 대안 A. 컨트롤러 안에서 조건문만 추가

- 장점: 가장 빠르다
- 단점: 현재 컨트롤러 집중도를 더 키우고, 다음 규칙 추가 때 다시 같은 파일에 조건이 쌓인다

### 대안 B. 최소 경계를 추가하고 컨트롤러는 orchestration만 맡긴다

- 장점: validation, 저장 대상 날짜, 집계 방어 규칙을 테스트 가능한 경계로 분리할 수 있다
- 장점: 이후 점심시간 차감, validation message, 과거 날짜 편집 같은 변경의 진입점을 만들 수 있다
- 단점: 작은 타입이 몇 개 더 생길 수 있다

## 선택한 방향

대안 B를 택한다.

- 시간 validation은 편집 적용 직전의 순수 경계가 소유한다
- 저장 대상 날짜는 displayed reference date가 stale하지 않을 때만 재사용하고, 자정 이후에는 current day로 전진시킨다
- picker의 기본값 동기화는 UI helper가 소유하지만, stale state 제거 규칙은 테스트로 고정한다
- `MenuBarPopoverControlling`는 실제 사용 맥락에 맞는 isolation 계약을 갖도록 조정한다

## 후속 리스크

- validation 결과를 나중에 사용자 메시지로 드러내고 싶어질 수 있다
- `MainPopoverViewController`의 책임 분리는 이번 refactor 이후에도 한 번 더 필요할 수 있다
