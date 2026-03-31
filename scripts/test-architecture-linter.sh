#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
tmp_output=$(mktemp)
trap 'rm -f "$tmp_output"' EXIT

python3 "$repo_root/scripts/check-architecture-invariants.py" \
  --config "$repo_root/scripts/fixtures/architecture-invariants/ok.toml"

if python3 "$repo_root/scripts/check-architecture-invariants.py" \
  --config "$repo_root/scripts/fixtures/architecture-invariants/bad.toml" >"$tmp_output" 2>&1; then
  echo "expected bad architecture fixture to fail" >&2
  cat "$tmp_output" >&2
  exit 1
fi

grep -q "forbidden-import:domain:UIKit" "$tmp_output"
grep -q "ownership:view-controller-layer" "$tmp_output"
grep -q "forbidden-content:no-task-detached" "$tmp_output"

echo "architecture invariant linter smoke tests passed"
