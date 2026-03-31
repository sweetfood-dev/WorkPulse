#!/usr/bin/env python3

from __future__ import annotations

import argparse
import fnmatch
import json
import pathlib
import sys


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Classify garbage collection findings into autofix, debt, or active-plan buckets.")
    parser.add_argument("--config", default=".golden-principles.toml", help="Path to golden principles TOML config.")
    parser.add_argument(
        "--findings",
        default="docs/generated/garbage-collection/latest.json",
        help="Path to the latest GC findings JSON file.",
    )
    parser.add_argument(
        "--output",
        default="docs/generated/garbage-collection/latest-actions.json",
        help="Path to write the classified actions JSON file.",
    )
    return parser.parse_args()


def parse_basic_string(value: str) -> str:
    result = []
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
        parts = []
        current = []
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
    new_entry = {}
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


def load_toml(path: pathlib.Path) -> dict:
    return parse_toml_subset(path.read_text(encoding="utf-8"))


def path_matches(globs: list[str], rel_path: str) -> bool:
    return any(fnmatch.fnmatch(rel_path, pattern) for pattern in globs)


def is_autofix_eligible(finding: dict, autofix_cfg: dict) -> bool:
    if str(autofix_cfg.get("enabled", "false")).lower() != "true":
        return False
    if finding.get("severity") not in {"minor", "advisory"}:
        return False
    if finding.get("confidence") != "high":
        return False
    if finding.get("next_action") != "cleanup-pr":
        return False
    if finding.get("kind") not in set(str(item) for item in autofix_cfg.get("allowed_finding_kinds", [])):
        return False
    rel_path = str(finding.get("path", ""))
    if not path_matches([str(item) for item in autofix_cfg.get("allowed_paths", [])], rel_path):
        return False
    if path_matches([str(item) for item in autofix_cfg.get("blocked_paths", [])], rel_path):
        return False
    return True


def main() -> int:
    args = parse_args()
    config_path = pathlib.Path(args.config).resolve()
    findings_path = pathlib.Path(args.findings).resolve()
    output_path = pathlib.Path(args.output).resolve()

    if not findings_path.exists():
        if output_path.exists():
            output_path.unlink()
        print(f"no findings artifact at {findings_path}; skipping classification")
        return 0

    config = load_toml(config_path)
    autofix_cfg = config.get("autofix", {})
    data = json.loads(findings_path.read_text(encoding="utf-8"))
    allow_autofix = data.get("overall_action") == "cleanup-pr"
    findings = data.get("findings", [])

    actions = {"autofix": [], "debt": [], "active_plan": []}
    for finding in findings:
        if allow_autofix and is_autofix_eligible(finding, autofix_cfg):
            actions["autofix"].append(finding)
        elif finding.get("next_action") == "active-plan":
            actions["active_plan"].append(finding)
        else:
            actions["debt"].append(finding)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(actions, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "classified garbage collection findings:"
        f" autofix={len(actions['autofix'])}"
        f" debt={len(actions['debt'])}"
        f" active_plan={len(actions['active_plan'])}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
