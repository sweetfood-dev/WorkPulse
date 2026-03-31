#!/usr/bin/env python3

from __future__ import annotations

import argparse
import datetime as dt
import json
import pathlib
import re
import subprocess
import sys
from dataclasses import dataclass


@dataclass(frozen=True)
class Finding:
    kind: str
    severity: str
    principle_id: str
    title: str
    path: str
    why: str
    confidence: str
    next_action: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run monthly garbage collection checks for the starter.")
    parser.add_argument("--config", default=".golden-principles.toml", help="Path to golden principles TOML config.")
    parser.add_argument("--write-report", action="store_true", help="Write the generated markdown report to disk.")
    parser.add_argument("--write-plan", action="store_true", help="Write an active cleanup plan skeleton when needed.")
    return parser.parse_args()


def ensure_list(value: object) -> list[str]:
    if value is None:
        return []
    if isinstance(value, list):
        return [str(item) for item in value]
    return [str(value)]


def parse_basic_string(value: str) -> str:
    result: list[str] = []
    index = 0
    escape_map = {"n": "\n", "r": "\r", "t": "\t", '"': '"', "\\": "\\"}
    while index < len(value):
        char = value[index]
        if char != "\\":
            result.append(char)
            index += 1
            continue
        index += 1
        if index >= len(value):
            raise ValueError("unterminated escape sequence in TOML string")
        escaped = value[index]
        result.append(escape_map.get(escaped, escaped))
        index += 1
    return "".join(result)


def parse_toml_value(raw_value: str) -> object:
    if raw_value.startswith('"') and raw_value.endswith('"'):
        return parse_basic_string(raw_value[1:-1])
    if raw_value.startswith("[") and raw_value.endswith("]"):
        inner = raw_value[1:-1].strip()
        if not inner:
            return []
        parts: list[str] = []
        current: list[str] = []
        in_string = False
        for char in inner:
            if char == '"':
                in_string = not in_string
                current.append(char)
                continue
            if char == "," and not in_string:
                parts.append("".join(current).strip())
                current = []
                continue
            current.append(char)
        parts.append("".join(current).strip())
        return [parse_toml_value(part) for part in parts if part]
    return raw_value


def ensure_table(root: dict, path: list[str]) -> dict:
    node = root
    for part in path:
        existing = node.get(part)
        if existing is None:
            existing = {}
            node[part] = existing
        if not isinstance(existing, dict):
            raise ValueError(f"table path collides with non-table key: {'.'.join(path)}")
        node = existing
    return node


def ensure_array_table(root: dict, path: list[str]) -> dict:
    parent = ensure_table(root, path[:-1]) if len(path) > 1 else root
    leaf = path[-1]
    existing = parent.get(leaf)
    if existing is None:
        existing = []
        parent[leaf] = existing
    if not isinstance(existing, list):
        raise ValueError(f"array table path collides with non-list key: {'.'.join(path)}")
    new_entry: dict = {}
    existing.append(new_entry)
    return new_entry


def parse_toml_subset(text: str) -> dict:
    root: dict = {}
    current: dict = root
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("[[") and line.endswith("]]"):
            path = [part.strip() for part in line[2:-2].strip().split(".") if part.strip()]
            current = ensure_array_table(root, path)
            continue
        if line.startswith("[") and line.endswith("]"):
            path = [part.strip() for part in line[1:-1].strip().split(".") if part.strip()]
            current = ensure_table(root, path)
            continue
        key, raw_value = line.split("=", 1)
        current[key.strip()] = parse_toml_value(raw_value.strip())
    return root


def load_config(config_path: pathlib.Path) -> dict:
    return parse_toml_subset(config_path.read_text(encoding="utf-8"))


def slurp_text_files(repo_root: pathlib.Path) -> str:
    allowed_suffixes = {".md", ".toml", ".yml", ".yaml", ".py", ".sh"}
    chunks: list[str] = []
    for path in repo_root.rglob("*"):
        if not path.is_file():
            continue
        if path.suffix not in allowed_suffixes:
            continue
        chunks.append(path.read_text(encoding="utf-8", errors="ignore"))
    return "\n".join(chunks)


def scan_orphan_docs(repo_root: pathlib.Path) -> list[Finding]:
    known_roots = {
        "README.md",
        "AGENTS.md",
        "ARCHITECTURE.md",
        "docs/BOOTSTRAP.md",
        "docs/GOLDEN_PRINCIPLES.md",
        "docs/ENGINEERING_RULES.md",
        "docs/TDD.md",
        "docs/PLANS.md",
        "docs/PRODUCT_SENSE.md",
        "docs/QUALITY_SCORE.md",
        "docs/RELIABILITY.md",
        "docs/SECURITY.md",
        "docs/DESIGN.md",
        "docs/FRONTEND.md",
        "docs/clean-architecture.md",
        "docs/ios-architecture.md",
        "docs/MCP_TOOLING.md",
        "docs/design-docs/index.md",
        "docs/product-specs/index.md",
        "docs/exec-plans/tech-debt-tracker.md",
    }
    corpus = slurp_text_files(repo_root)
    findings: list[Finding] = []
    for path in repo_root.rglob("*.md"):
        rel = path.relative_to(repo_root).as_posix()
        if rel in known_roots:
            continue
        if rel.startswith("docs/generated/garbage-collection/"):
            continue
        if rel.startswith("docs/exec-plans/active/"):
            continue
        if rel.startswith("docs/exec-plans/completed/"):
            continue
        if rel.endswith(".gitkeep"):
            continue
        basename = path.name
        mentions = corpus.count(rel) + corpus.count(f"./{rel}") + corpus.count(basename)
        if mentions > 1:
            continue
        findings.append(
            Finding(
                kind="orphan-doc",
                severity="minor",
                principle_id="GP-02",
                title="Orphan doc candidate",
                path=rel,
                why="The document is not referenced elsewhere in the repo text corpus and may no longer be a source of truth.",
                confidence="medium",
                next_action="debt",
            )
        )
    return findings


def scan_stale_active_plans(repo_root: pathlib.Path, stale_days: int) -> list[Finding]:
    findings: list[Finding] = []
    active_dir = repo_root / "docs/exec-plans/active"
    today = dt.date.today()
    for path in sorted(active_dir.glob("*.md")):
        match = re.match(r"(\d{4}-\d{2}-\d{2})-", path.name)
        if match:
            created = dt.date.fromisoformat(match.group(1))
        else:
            created = dt.date.fromtimestamp(path.stat().st_mtime)
        age = (today - created).days
        if age <= stale_days:
            continue
        findings.append(
            Finding(
                kind="stale-active-plan",
                severity="major",
                principle_id="GP-03",
                title="Stale active plan",
                path=path.relative_to(repo_root).as_posix(),
                why=f"Active plan has been open for {age} days, which exceeds the configured stale threshold of {stale_days} days.",
                confidence="high",
                next_action="active-plan",
            )
        )
    return findings


def scan_overdue_debt_reviews(repo_root: pathlib.Path, grace_days: int) -> list[Finding]:
    tracker = repo_root / "docs/exec-plans/tech-debt-tracker.md"
    findings: list[Finding] = []
    today = dt.date.today()
    for raw_line in tracker.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line.startswith("|") or "_empty_" in line or "ID |" in line or "---" in line:
            continue
        cells = [cell.strip() for cell in line.strip("|").split("|")]
        if len(cells) < 12:
            continue
        debt_id = cells[0]
        next_review = cells[9]
        if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", next_review):
            continue
        due = dt.date.fromisoformat(next_review)
        overdue_days = (today - due).days
        if overdue_days <= grace_days:
            continue
        findings.append(
            Finding(
                kind="overdue-debt-review",
                severity="minor",
                principle_id="GP-02",
                title="Overdue debt review",
                path=tracker.relative_to(repo_root).as_posix(),
                why=f"Debt item {debt_id} is overdue for review by {overdue_days} days.",
                confidence="high",
                next_action="debt",
            )
        )
    return findings


def scan_expired_exemptions(repo_root: pathlib.Path) -> list[Finding]:
    result = subprocess.run(
        [sys.executable, str(repo_root / "scripts/check-architecture-invariants.py"), "--config", str(repo_root / ".architecture-invariants.toml")],
        check=False,
        capture_output=True,
        text=True,
    )
    findings: list[Finding] = []
    for line in result.stdout.splitlines() + result.stderr.splitlines():
        if "expired-exemption:" not in line:
            continue
        parts = line.split(" ", 2)
        if len(parts) < 3:
            continue
        _, path, rest = parts
        rule_id, message = rest.split(": ", 1)
        findings.append(
            Finding(
                kind="expired-architecture-exemption",
                severity="major",
                principle_id="GP-05",
                title="Expired architecture exemption",
                path=path,
                why=message,
                confidence="high",
                next_action="cleanup-pr",
            )
        )
    return findings


def scan_stale_generated_reports(repo_root: pathlib.Path, retention: int) -> list[Finding]:
    report_dir = repo_root / "docs/generated/garbage-collection"
    report_files = sorted([path for path in report_dir.glob("*-report.md") if path.is_file()], reverse=True)
    findings: list[Finding] = []
    for path in report_files[retention:]:
        findings.append(
            Finding(
                kind="stale-generated-gc-report",
                severity="advisory",
                principle_id="GP-02",
                title="Stale generated GC report",
                path=path.relative_to(repo_root).as_posix(),
                why="Generated garbage collection reports beyond the retention window should be removed by an automated cleanup PR.",
                confidence="high",
                next_action="cleanup-pr",
            )
        )
    return findings


def choose_overall_action(findings: list[Finding], max_cleanup_pr_findings: int) -> str:
    if not findings:
        return "none"
    if any(item.next_action == "active-plan" for item in findings):
        return "active-plan"
    cleanup_candidates = [item for item in findings if item.next_action == "cleanup-pr"]
    if cleanup_candidates and len(cleanup_candidates) <= max_cleanup_pr_findings and len(cleanup_candidates) == len(findings):
        return "cleanup-pr"
    return "debt"


def render_report(findings: list[Finding], overall_action: str) -> str:
    lines = [
        "# Monthly Garbage Collection Report",
        "",
        f"- Generated on: {dt.date.today().isoformat()}",
        f"- Overall next action: `{overall_action}`",
        "",
    ]

    if not findings:
        lines.append("No findings.")
        return "\n".join(lines) + "\n"

    lines.extend(
        [
            "| Severity | Principle | Title | Path | Confidence | Next Action |",
            "| --- | --- | --- | --- | --- | --- |",
        ]
    )
    for item in findings:
        lines.append(
            f"| `{item.severity}` | `{item.principle_id}` | {item.title} | `{item.path}` | `{item.confidence}` | `{item.next_action}` |"
        )

    lines.append("")
    lines.append("## Findings")
    lines.append("")
    for item in findings:
        lines.append(f"### {item.title}")
        lines.append(f"- severity: `{item.severity}`")
        lines.append(f"- kind: `{item.kind}`")
        lines.append(f"- principle_id: `{item.principle_id}`")
        lines.append(f"- path: `{item.path}`")
        lines.append(f"- confidence: `{item.confidence}`")
        lines.append(f"- next action: `{item.next_action}`")
        lines.append(f"- why: {item.why}")
        lines.append("")

    lines.extend(
        [
            "## Follow-up Agent Prompt",
            "",
            "Use this prompt when running the monthly Codex garbage collection follow-up:",
            "",
            "```text",
            "Review this repository for garbage collection and golden-principles drift.",
            "",
            "Report only:",
            "1. files that are no longer referenced by build graph, source, docs, scripts, or config",
            "2. dead code candidates with supporting evidence",
            "3. unused dependencies with supporting evidence",
            "4. expired exemptions",
            "5. stale active plans or debt items",
            "6. duplicate or conflicting source-of-truth docs",
            "7. repeated Minor/Major violations grouped by principle",
            "",
            "For each finding, include:",
            "- severity",
            "- principle_id",
            "- file or doc reference",
            "- why it matters",
            "- confidence",
            "- recommended next action: cleanup-pr, debt, or active-plan",
            "",
            "Be conservative.",
            "Do not propose broad rewrites unless duplication or drift is already causing review noise.",
            "```",
            "",
        ]
    )

    return "\n".join(lines)


def render_json(findings: list[Finding], overall_action: str) -> str:
    payload = {
        "generated_on": dt.date.today().isoformat(),
        "overall_action": overall_action,
        "findings": [
            {
                "kind": item.kind,
                "severity": item.severity,
                "principle_id": item.principle_id,
                "title": item.title,
                "path": item.path,
                "why": item.why,
                "confidence": item.confidence,
                "next_action": item.next_action,
            }
            for item in findings
        ],
    }
    return json.dumps(payload, indent=2, sort_keys=True) + "\n"


def render_plan(findings: list[Finding]) -> str:
    lines = [
        "# Monthly GC Cleanup Plan",
        "",
        "- status: active",
        f"- owner: gc-curator",
        f"- generated: {dt.date.today().isoformat()}",
        "",
        "## Goal",
        "",
        "Address monthly garbage collection findings that require coordinated cleanup rather than a trivial mechanical PR.",
        "",
        "## Scope",
        "",
    ]
    for item in findings:
        lines.append(f"- {item.title} ({item.principle_id})")
    lines.extend(["", "## Execution", ""])
    for item in findings:
        lines.append(f"- [ ] Triage and resolve `{item.path}`: {item.why}")
    lines.append("")
    lines.append("## Verification")
    lines.append("")
    lines.append("- [ ] Relevant tests or checks pass")
    lines.append("- [ ] Related docs and debt tracker are updated")
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    args = parse_args()
    config_path = pathlib.Path(args.config).resolve()
    repo_root = config_path.parent
    config = load_config(config_path)
    gc_cfg = config.get("garbage_collection", {})
    stale_days = int(str(gc_cfg.get("stale_active_plan_days", "45")))
    grace_days = int(str(gc_cfg.get("debt_review_grace_days", "30")))
    max_cleanup_pr_findings = int(str(gc_cfg.get("max_cleanup_pr_findings", "5")))
    retention = int(str(gc_cfg.get("report_retention", "6")))

    findings: list[Finding] = []
    findings.extend(scan_expired_exemptions(repo_root))
    findings.extend(scan_stale_active_plans(repo_root, stale_days))
    findings.extend(scan_overdue_debt_reviews(repo_root, grace_days))
    findings.extend(scan_orphan_docs(repo_root))
    findings.extend(scan_stale_generated_reports(repo_root, retention))

    overall_action = choose_overall_action(findings, max_cleanup_pr_findings)
    report = render_report(findings, overall_action)
    json_payload = render_json(findings, overall_action)
    print(report, end="")

    if args.write_report:
        report_dir = repo_root / str(gc_cfg.get("report_dir", "docs/generated/garbage-collection"))
        report_dir.mkdir(parents=True, exist_ok=True)
        latest_json_path = report_dir / "latest.json"
        if findings:
            report_path = report_dir / f"{dt.date.today().strftime('%Y-%m')}-report.md"
            report_path.write_text(report, encoding="utf-8")
            latest_json_path.write_text(json_payload, encoding="utf-8")
        elif latest_json_path.exists():
            latest_json_path.unlink()

    if args.write_plan and overall_action == "active-plan":
        plan_dir = repo_root / str(gc_cfg.get("active_plan_dir", "docs/exec-plans/active"))
        plan_dir.mkdir(parents=True, exist_ok=True)
        plan_path = plan_dir / f"{dt.date.today().strftime('%Y-%m')}-golden-principles-gc-cleanup.md"
        plan_path.write_text(render_plan([item for item in findings if item.next_action == "active-plan"]), encoding="utf-8")

    return 0


if __name__ == "__main__":
    sys.exit(main())
