#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
missing=0

# Machine-checkable subset of the starter baseline contract defined in docs/BOOTSTRAP.md.

required_files='
AGENTS.md
ARCHITECTURE.md
README.md
Makefile
docs/BOOTSTRAP.md
docs/DESIGN.md
docs/ENGINEERING_RULES.md
docs/GOLDEN_PRINCIPLES.md
docs/PLANS.md
docs/PRODUCT_SENSE.md
docs/QUALITY_SCORE.md
docs/TDD.md
docs/design-docs/index.md
docs/product-specs/index.md
docs/exec-plans/tech-debt-tracker.md
.golden-principles.toml
.codex/config.toml
.codex/agents/README.md
.codex/agents/cleanup-patcher.toml
.codex/agents/gc-curator.toml
.codex/agents/spec-plan-scout.toml
.codex/agents/verification-reviewer.toml
.codex/agents/docs-gardener.toml
scripts/check-required-docs.sh
scripts/check-markdown-relative-links.sh
scripts/check-golden-principles.py
scripts/classify-gc-actions.py
scripts/apply-safe-cleanups.py
scripts/run-garbage-collection.py
scripts/test-golden-principles.sh
.github/workflows/docs-verify.yml
.github/workflows/golden-principles.yml
.github/workflows/monthly-garbage-collection.yml
'

required_dirs='
docs/exec-plans/active
docs/exec-plans/completed
docs/generated
docs/generated/garbage-collection
docs/references
scripts
.github/workflows
'

for path in $required_files; do
  if [ ! -f "$repo_root/$path" ]; then
    echo "missing file: $path" >&2
    missing=1
  fi
done

for path in $required_dirs; do
  if [ ! -d "$repo_root/$path" ]; then
    echo "missing directory: $path" >&2
    missing=1
  fi
done

if [ "$missing" -ne 0 ]; then
  exit 1
fi

echo "required docs and directories are present"
