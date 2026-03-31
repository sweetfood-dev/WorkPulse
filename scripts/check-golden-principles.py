#!/usr/bin/env python3

from __future__ import annotations

import argparse
import pathlib
import subprocess
import sys
from dataclasses import dataclass


@dataclass(frozen=True)
class Violation:
    level: str
    rule_id: str
    path: str
    message: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Check golden principles registry and linked rule owners.")
    parser.add_argument("--config", default=".golden-principles.toml", help="Path to golden principles TOML config.")
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


def architecture_invariants_check(repo_root: pathlib.Path) -> list[Violation]:
    result = subprocess.run(
        [sys.executable, str(repo_root / "scripts/check-architecture-invariants.py"), "--config", str(repo_root / ".architecture-invariants.toml")],
        check=False,
        capture_output=True,
        text=True,
    )
    violations: list[Violation] = []
    for line in result.stdout.splitlines() + result.stderr.splitlines():
        if not line.startswith(("ERROR ", "WARN ")):
            continue
        level, rest = line.split(" ", 1)
        path, rest = rest.split(" ", 1)
        rule_id, message = rest.split(": ", 1)
        violations.append(Violation(level=level.lower(), rule_id=rule_id, path=path, message=message))
    return violations


def main() -> int:
    args = parse_args()
    config_path = pathlib.Path(args.config).resolve()
    repo_root = config_path.parent
    config = load_config(config_path)

    violations: list[Violation] = []
    seen_ids: set[str] = set()

    for principle in config.get("principles", []):
        principle_id = str(principle["id"])
        if principle_id in seen_ids:
            violations.append(Violation("error", "duplicate-principle-id", config_path.name, f"Duplicate principle id: {principle_id}"))
        seen_ids.add(principle_id)

        owners = ensure_list(principle.get("owners"))
        if not owners:
            violations.append(Violation("error", f"{principle_id}:owners", config_path.name, "Principle has no owner docs."))

        for owner in owners:
            owner_path = repo_root / owner
            if not owner_path.exists():
                violations.append(Violation("error", f"{principle_id}:missing-owner", owner, f"Owner path does not exist for {principle_id}."))

        if "architecture_invariants" in ensure_list(principle.get("machine_checks")):
            for item in architecture_invariants_check(repo_root):
                level = "error" if item.level == "error" else "warn"
                violations.append(
                    Violation(
                        level,
                        f"{principle_id}:{item.rule_id}",
                        item.path,
                        item.message,
                    )
                )

    error_count = sum(1 for item in violations if item.level == "error")
    warn_count = sum(1 for item in violations if item.level == "warn")

    for violation in violations:
        print(f"{violation.level.upper()} {violation.path} {violation.rule_id}: {violation.message}")

    if error_count:
        print(f"golden principles failed: {error_count} error(s), {warn_count} warning(s)", file=sys.stderr)
        return 1

    print(f"golden principles passed: {len(seen_ids)} principle(s) checked")
    return 0


if __name__ == "__main__":
    sys.exit(main())
