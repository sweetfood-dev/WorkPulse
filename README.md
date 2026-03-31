# WorkPulse

WorkPulse는 macOS 메뉴바 기반 근태/근무시간 추적 앱입니다.
이 저장소는 제품 코드와 함께 유지될 운영 문서, 아키텍처 규칙, custom subagent, 검증 스크립트의 기준점을 담습니다.

## What Lives Here

- `AGENTS.md`: 짧은 읽기 지도
- `ARCHITECTURE.md`: 저장소 구조와 문서 라우팅 규칙
- `docs/`: 제품 운영 문서, 계획, 디자인 근거, 제품 스펙
- `.architecture-invariants.toml`: machine-checkable architecture invariant 설정
- `.golden-principles.toml`: repo-level golden principles registry와 garbage collection 설정
- `.codex/agents/`: WorkPulse 전용 custom subagent 정의
- `scripts/`와 `.github/workflows/`: 문서 검증, architecture invariant, golden principles, garbage collection 도구

## First Reads

1. [`AGENTS.md`](./AGENTS.md)
2. [`ARCHITECTURE.md`](./ARCHITECTURE.md)
3. [`docs/PLANS.md`](./docs/PLANS.md)
4. [`docs/macos-architecture.md`](./docs/macos-architecture.md)
5. 필요하면 [`docs/GOLDEN_PRINCIPLES.md`](./docs/GOLDEN_PRINCIPLES.md)

## Verification

```sh
make verify
```

기본 검증은 아래를 다룹니다.

- 필수 운영 문서와 디렉터리 존재 여부
- markdown 상대 링크 무결성

`docs/clean-architecture.md`를 유지하는 프로젝트라면 아래도 사용할 수 있습니다.

```sh
make verify-architecture
make test-architecture-linter
make verify-all
```

- `make verify-architecture`: `.architecture-invariants.toml` 기준의 layer ownership / forbidden import / exemption 검증
- `make test-architecture-linter`: architecture linter smoke test
- `make verify-all`: 문서 검증, architecture invariant, golden principles smoke/registry 검증을 함께 실행

`docs/GOLDEN_PRINCIPLES.md`를 유지하는 WorkPulse 운영 방식에서는 아래도 사용할 수 있습니다.

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
- 실제 제품 스택과 제품 코드는 이 저장소 위에 추가합니다.
- `docs/clean-architecture.md`를 유지하는 한 `.architecture-invariants.toml`과 `scripts/check-architecture-invariants.py`도 함께 관리합니다.
- `docs/GOLDEN_PRINCIPLES.md`를 유지하는 한 `.golden-principles.toml`, 관련 scripts, workflows, subagent도 함께 관리합니다.
- 기본 auto-fix 범위는 `docs/generated/garbage-collection/` 아래의 generated cleanup에만 제한됩니다.
