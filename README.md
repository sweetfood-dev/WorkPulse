# Harness Starter

문서 중심의 harness repo를 새 프로젝트에 빠르게 이식하기 위한 starter template입니다.

## What You Get

- `AGENTS.md`: 짧은 읽기 지도
- `ARCHITECTURE.md`: 저장소 구조와 문서 라우팅 규칙
- `docs/`: core 운영 문서와 프로젝트별 optional specialized doc
- `.architecture-invariants.toml`: machine-checkable architecture rule 예시 설정
- `.golden-principles.toml`: repo-level golden principles registry와 garbage collection 설정
- `.codex/agents/`: 프로젝트 전용 custom subagent 정의
- `scripts/`와 `.github/workflows/`: 문서 검증, architecture invariant, golden principles, garbage collection 도구

## Quick Start

1. 이 저장소를 새 프로젝트용으로 복사하거나 템플릿으로 사용합니다.
2. starter baseline contract와 상세 이식 절차는 [`docs/BOOTSTRAP.md`](./docs/BOOTSTRAP.md)를 따라갑니다.
3. 프로젝트에 맞게 문서를 정리한 뒤 `make verify`로 기본 문서 검증을 실행합니다.
4. `docs/clean-architecture.md`를 유지하는 프로젝트라면 `make verify-architecture`도 프로젝트 구조에 맞게 설정합니다.
5. starter baseline에는 golden principles와 monthly garbage collection이 포함됩니다. 유지할 경우 owner와 allowlist를 프로젝트 기준으로 맞추고, 제거할 경우 관련 registry/scripts/workflow를 함께 교체하거나 삭제합니다.

## Verification

```sh
make verify
```

현재 검증은 아래를 다룹니다.

- 필수 템플릿 문서와 디렉터리 존재 여부
- markdown 상대 링크 무결성

`docs/clean-architecture.md`를 유지하는 프로젝트라면 아래도 사용할 수 있습니다.

```sh
make verify-architecture
make test-architecture-linter
make verify-all
```

- `make verify-architecture`: `.architecture-invariants.toml` 기준의 layer ownership / forbidden import / exemption 검증
- `make test-architecture-linter`: starter에 포함된 linter smoke test
- `make verify-all`: 문서 검증, architecture invariant, golden principles smoke/registry 검증을 함께 실행

starter baseline의 `docs/GOLDEN_PRINCIPLES.md`를 유지하는 프로젝트라면 아래도 사용할 수 있습니다.

```sh
make verify-golden-principles
make test-golden-principles
make garbage-collect
make classify-gc-actions
make apply-safe-cleanups
```

- `make verify-golden-principles`: golden principles registry와 owner 연결 검증
- `make test-golden-principles`: starter의 golden principles / garbage collection smoke test
- `make garbage-collect`: 월간 garbage collection report와 필요시 cleanup plan skeleton 생성
- `make classify-gc-actions`: monthly GC finding을 `autofix`, `debt`, `active-plan`으로 분류
- `make apply-safe-cleanups`: allowlist 안의 high-confidence cleanup만 실제 파일 변경으로 적용

## Notes

- `AGENTS.md`는 계속 짧게 유지합니다.
- 저장소 수준 분류 기준은 `ARCHITECTURE.md`가 설명합니다.
- 프로젝트별 서브에이전트는 `.codex/agents/`에서 조정합니다.
- 실제 제품 스택에 맞는 CI, lint, test 규칙은 이 템플릿 위에 추가합니다.
- `docs/BOOTSTRAP.md`가 starter baseline contract와 customization 절차의 owner입니다.
- `docs/clean-architecture.md`를 유지하는 프로젝트는 `.architecture-invariants.toml`과 `scripts/check-architecture-invariants.py`도 함께 맞춤화합니다.
- `docs/GOLDEN_PRINCIPLES.md`를 유지하는 프로젝트는 `.golden-principles.toml`, `scripts/check-golden-principles.py`, `scripts/run-garbage-collection.py`, `scripts/classify-gc-actions.py`, `scripts/apply-safe-cleanups.py`, 관련 subagent, monthly workflow도 함께 맞춤화합니다.
- starter의 기본 auto-fix 범위는 `docs/generated/garbage-collection/` 아래의 generated cleanup에만 제한됩니다.
- 템플릿 제작 이력은 starter repo에 남기지 않고, 새 프로젝트의 실제 이력만 `docs/exec-plans/`에 쌓습니다.
