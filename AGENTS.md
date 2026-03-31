# AGENTS.md

이 파일은 지도 역할만 합니다.
상세 설명, 운영 기준, 판단 규칙은 아래 문서를 기준으로 봅니다.

## Repo Map

```text
README.md
AGENTS.md
ARCHITECTURE.md
.architecture-invariants.toml
.golden-principles.toml
docs/
├── GOLDEN_PRINCIPLES.md
├── ENGINEERING_RULES.md
├── MCP_TOOLING.md
├── TDD.md
├── PLANS.md
├── PRODUCT_SENSE.md
├── QUALITY_SCORE.md
├── RELIABILITY.md
├── SECURITY.md
├── DESIGN.md
├── FRONTEND.md
├── clean-architecture.md
├── ios-architecture.md
├── BOOTSTRAP.md
├── design-docs/
├── exec-plans/
├── product-specs/
├── generated/
└── references/
```

먼저 [`ARCHITECTURE.md`](./ARCHITECTURE.md)를 읽습니다.
starter baseline contract와 customization 절차는 [`docs/BOOTSTRAP.md`](./docs/BOOTSTRAP.md)를 따릅니다.
specialized guidance와 문서 라우팅은 [`ARCHITECTURE.md`](./ARCHITECTURE.md)가 설명합니다.
문서를 어디에 둘지 헷갈리면 [`ARCHITECTURE.md`](./ARCHITECTURE.md)의 분류 기준을 먼저 봅니다.
리포지토리 수준의 golden principles와 월간 garbage collection 기준은 [`docs/GOLDEN_PRINCIPLES.md`](./docs/GOLDEN_PRINCIPLES.md)를 봅니다.
레이어 경계나 구조 규칙을 바꾸면 [`docs/clean-architecture.md`](./docs/clean-architecture.md)와 [`.architecture-invariants.toml`](./.architecture-invariants.toml)을 함께 봅니다.
