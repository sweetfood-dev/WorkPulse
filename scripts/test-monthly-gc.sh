#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

create_tracker() {
  target_dir="$1"
  mkdir -p "$target_dir/docs/exec-plans" "$target_dir/docs/generated/garbage-collection" "$target_dir/docs/exec-plans/active"
  cat >"$target_dir/docs/exec-plans/tech-debt-tracker.md" <<'EOF'
# tech-debt-tracker.md

| ID | principle_id | 제목 | owner | 카테고리 | 영향 | 위험 | 승격 조건 | 마지막 검토일 | 다음 검토 시점 | 상태 | source report / source plan |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| _empty_ | _GP-XX_ | _프로젝트별 항목 추가_ | _unassigned_ | _category_ | _impact_ | _risk_ | _promotion trigger_ | _YYYY-MM-DD_ | _review point_ | _backlog_ | _generated report or active plan_ |
EOF
}

# cleanup-pr path with classify/apply-safe-cleanups
cleanup_dir="$tmp_dir/cleanup"
mkdir -p "$cleanup_dir"
cp "$repo_root/.golden-principles.toml" "$cleanup_dir/.golden-principles.toml"
create_tracker "$cleanup_dir"

cat >"$cleanup_dir/docs/generated/garbage-collection/2026-01-report.md" <<'EOF'
# Old Report
EOF

cat >"$cleanup_dir/docs/generated/garbage-collection/2026-02-report.md" <<'EOF'
# Current Report
EOF

cat >"$cleanup_dir/docs/generated/garbage-collection/latest.json" <<'EOF'
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
  --config "$cleanup_dir/.golden-principles.toml" \
  --findings "$cleanup_dir/docs/generated/garbage-collection/latest.json" \
  --output "$cleanup_dir/docs/generated/garbage-collection/latest-actions.json"

grep -q '"autofix"' "$cleanup_dir/docs/generated/garbage-collection/latest-actions.json"
grep -q '2026-01-report.md' "$cleanup_dir/docs/generated/garbage-collection/latest-actions.json"

python3 "$repo_root/scripts/apply-safe-cleanups.py" \
  --config "$cleanup_dir/.golden-principles.toml" \
  --actions "$cleanup_dir/docs/generated/garbage-collection/latest-actions.json" >"$cleanup_dir/apply.out"

test ! -f "$cleanup_dir/docs/generated/garbage-collection/2026-01-report.md"
test -f "$cleanup_dir/docs/generated/garbage-collection/index.md"
grep -q '2026-02-report.md' "$cleanup_dir/docs/generated/garbage-collection/index.md"

# active-plan path with write-plan
active_plan_dir="$tmp_dir/active-plan"
mkdir -p "$active_plan_dir"
cp "$repo_root/.golden-principles.toml" "$active_plan_dir/.golden-principles.toml"
create_tracker "$active_plan_dir"

cat >"$active_plan_dir/docs/exec-plans/active/2025-01-01-stale-plan.md" <<'EOF'
# stale plan
EOF

python3 "$repo_root/scripts/run-garbage-collection.py" \
  --config "$active_plan_dir/.golden-principles.toml" \
  --write-plan >"$active_plan_dir/report.out"

grep -q 'Overall next action: `active-plan`' "$active_plan_dir/report.out"
generated_plan=$(find "$active_plan_dir/docs/exec-plans/active" -name '*-golden-principles-gc-cleanup.md' -print | head -n 1)
test -n "$generated_plan"
grep -q 'Monthly GC Cleanup Plan' "$generated_plan"

# no-findings path should clear stale latest.json when writing reports
no_findings_dir="$tmp_dir/no-findings"
mkdir -p "$no_findings_dir"
cp "$repo_root/.golden-principles.toml" "$no_findings_dir/.golden-principles.toml"
create_tracker "$no_findings_dir"

cat >"$no_findings_dir/docs/generated/garbage-collection/latest.json" <<'EOF'
{"generated_on":"2026-03-30","overall_action":"cleanup-pr","findings":[]}
EOF

python3 "$repo_root/scripts/run-garbage-collection.py" \
  --config "$no_findings_dir/.golden-principles.toml" \
  --write-report >"$no_findings_dir/report.out"

grep -q 'No findings.' "$no_findings_dir/report.out"
test ! -f "$no_findings_dir/docs/generated/garbage-collection/latest.json"

echo "monthly garbage collection smoke tests passed"
