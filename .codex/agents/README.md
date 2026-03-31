# Project Subagents

이 디렉터리는 이 프로젝트에서 반복적으로 유용한 custom subagent 정의를 담습니다.

현재 기본 세트는 아래 5개입니다.

- `spec-plan-scout.toml`
  - 요구사항을 구현 전에 분해하고 범위, 제약, 성공 기준, 실행 슬라이스를 정리
- `verification-reviewer.toml`
  - 구현 후 correctness, regression, missing tests, reliability, security risk를 점검
- `docs-gardener.toml`
  - durable knowledge 변화가 생겼을 때 어떤 문서를 갱신해야 하는지 맞추고 문서 일관성을 복원
- `gc-curator.toml`
  - 월간 garbage collection finding을 cleanup PR, debt item, active plan 중 어디로 보낼지 triage
- `cleanup-patcher.toml`
  - allowlist 안의 high-confidence cleanup finding만 실제 파일 변경으로 적용

의도적으로 만들지 않은 역할도 있습니다.

- generic implementation agent
  - built-in `worker`가 이미 충분히 일반적인 구현 역할을 담당합니다.
- generic exploration agent
  - built-in `explorer`가 이미 코드 탐색 역할을 담당합니다.
- broad domain specialist
  - 도메인별 전문성은 custom subagent보다 skill을 붙이는 편이 더 낫습니다.
