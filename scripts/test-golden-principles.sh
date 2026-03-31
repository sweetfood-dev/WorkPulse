#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
tmp_output=$(mktemp)
tmp_dir=$(mktemp -d)
trap 'rm -f "$tmp_output"; rm -rf "$tmp_dir"' EXIT

python3 "$repo_root/scripts/check-golden-principles.py" --config "$repo_root/.golden-principles.toml"
python3 "$repo_root/scripts/run-garbage-collection.py" --config "$repo_root/.golden-principles.toml" >"$tmp_output"

grep -q "Monthly Garbage Collection Report" "$tmp_output"
grep -q "Overall next action" "$tmp_output"

cp "$repo_root/.golden-principles.toml" "$tmp_dir/.golden-principles.toml"
mkdir -p "$tmp_dir/docs/generated/garbage-collection"

cat >"$tmp_dir/docs/generated/garbage-collection/2026-01-report.md" <<'EOF'
# Old Report
EOF

cat >"$tmp_dir/docs/generated/garbage-collection/2026-02-report.md" <<'EOF'
# Current Report
EOF

cat >"$tmp_dir/docs/generated/garbage-collection/latest.json" <<'EOF'
{
  "generated_on": "2026-03-30",
  "overall_action": "cleanup-pr",
  "findings": [
    {
      "kind": "stale-generated-gc-report",
      "severity": "advisory",
      "principle_id": "GP-02",
      "title": "Stale generated GC report",
      "path": "docs/generated/garbage-collection/2026-01-report.md",
      "why": "Generated garbage collection reports beyond the retention window should be removed by an automated cleanup PR.",
      "confidence": "high",
      "next_action": "cleanup-pr"
    }
  ]
}
EOF

python3 "$repo_root/scripts/classify-gc-actions.py" \
  --config "$tmp_dir/.golden-principles.toml" \
  --findings "$tmp_dir/docs/generated/garbage-collection/latest.json" \
  --output "$tmp_dir/docs/generated/garbage-collection/latest-actions.json"

grep -q '"autofix"' "$tmp_dir/docs/generated/garbage-collection/latest-actions.json"
grep -q '2026-01-report.md' "$tmp_dir/docs/generated/garbage-collection/latest-actions.json"

python3 "$repo_root/scripts/apply-safe-cleanups.py" \
  --config "$tmp_dir/.golden-principles.toml" \
  --actions "$tmp_dir/docs/generated/garbage-collection/latest-actions.json" >"$tmp_dir/apply.out"

test ! -f "$tmp_dir/docs/generated/garbage-collection/2026-01-report.md"
test -f "$tmp_dir/docs/generated/garbage-collection/index.md"
grep -q '2026-02-report.md' "$tmp_dir/docs/generated/garbage-collection/index.md"

echo "golden principles smoke tests passed"
