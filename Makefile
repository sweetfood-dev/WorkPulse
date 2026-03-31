PYTHON ?= python3

.PHONY: verify verify-architecture verify-golden-principles test-architecture-linter test-golden-principles garbage-collect classify-gc-actions apply-safe-cleanups verify-all

verify:
	bash scripts/check-required-docs.sh
	bash scripts/check-markdown-relative-links.sh

verify-architecture:
	$(PYTHON) scripts/check-architecture-invariants.py --config .architecture-invariants.toml

verify-golden-principles:
	$(PYTHON) scripts/check-golden-principles.py --config .golden-principles.toml

test-architecture-linter:
	bash scripts/test-architecture-linter.sh

test-golden-principles:
	bash scripts/test-golden-principles.sh

garbage-collect:
	$(PYTHON) scripts/run-garbage-collection.py --config .golden-principles.toml --write-report --write-plan

classify-gc-actions:
	$(PYTHON) scripts/classify-gc-actions.py --config .golden-principles.toml

apply-safe-cleanups:
	$(PYTHON) scripts/apply-safe-cleanups.py --config .golden-principles.toml

verify-all: verify test-architecture-linter verify-architecture test-golden-principles verify-golden-principles
