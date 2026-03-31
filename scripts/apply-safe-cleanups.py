#!/usr/bin/env python3

from __future__ import annotations

import argparse
import fnmatch
import json
import pathlib
import sys


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Apply allowlisted, high-confidence garbage collection cleanups.")
    parser.add_argument("--config", default=".golden-principles.toml", help="Path to golden principles TOML config.")
    parser.add_argument(
        "--actions",
        default="docs/generated/garbage-collection/latest-actions.json",
        help="Path to the classified GC actions JSON file.",
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


def build_index(report_dir: pathlib.Path) -> str:
    lines = [
        "# Garbage Collection Reports",
        "",
        "이 문서는 generated monthly garbage collection report index입니다.",
        "",
    ]
    reports = sorted(
        [
            path.name
            for path in report_dir.glob("*-report.md")
            if path.is_file()
        ],
        reverse=True,
    )
    if not reports:
        lines.append("No generated reports.")
    else:
        for name in reports:
            lines.append(f"- [{name}](./{name})")
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    args = parse_args()
    config_path = pathlib.Path(args.config).resolve()
    actions_path = pathlib.Path(args.actions).resolve()
    repo_root = config_path.parent

    if not actions_path.exists():
        print(f"no classified actions at {actions_path}; skipping safe cleanups")
        return 0

    config = load_toml(config_path)
    autofix_cfg = config.get("autofix", {})
    allowed_paths = [str(item) for item in autofix_cfg.get("allowed_paths", [])]
    blocked_paths = [str(item) for item in autofix_cfg.get("blocked_paths", [])]
    max_files_changed = int(str(autofix_cfg.get("max_files_changed", "5")))
    retention = int(str(config.get("garbage_collection", {}).get("report_retention", "6")))
    report_dir = repo_root / str(config.get("garbage_collection", {}).get("report_dir", "docs/generated/garbage-collection"))

    actions = json.loads(actions_path.read_text(encoding="utf-8"))
    autofix = actions.get("autofix", [])

    if autofix and len(autofix) + 1 > max_files_changed:
        print(f"autofix batch exceeds max_files_changed={max_files_changed}; skipping safe cleanups")
        return 0

    changed_paths: list[str] = []
    for finding in autofix:
        rel_path = str(finding.get("path", ""))
        kind = str(finding.get("kind", ""))
        if not path_matches(allowed_paths, rel_path):
            continue
        if path_matches(blocked_paths, rel_path):
            continue
        if kind != "stale-generated-gc-report":
            continue

        target = repo_root / rel_path
        if target.exists() and target.is_file():
            target.unlink()
            changed_paths.append(rel_path)

    reports = sorted([path for path in report_dir.glob("*-report.md") if path.is_file()], reverse=True)
    for path in reports[retention:]:
        rel_path = path.relative_to(repo_root).as_posix()
        if path_matches(blocked_paths, rel_path):
            continue
        path.unlink()
        changed_paths.append(rel_path)

    if report_dir.exists():
        index_path = report_dir / "index.md"
        index_path.write_text(build_index(report_dir), encoding="utf-8")
        changed_paths.append(index_path.relative_to(repo_root).as_posix())

    deduped = []
    seen = set()
    for path in changed_paths:
        if path in seen:
            continue
        seen.add(path)
        deduped.append(path)

    if deduped:
        print("applied safe cleanups:")
        for path in deduped:
            print(f"- {path}")
    else:
        print("no safe cleanups applied")
    return 0


if __name__ == "__main__":
    sys.exit(main())
