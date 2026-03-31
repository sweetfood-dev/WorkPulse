#!/usr/bin/env python3

from __future__ import annotations

import argparse
import datetime as dt
import fnmatch
import pathlib
import re
import sys
from dataclasses import dataclass


@dataclass(frozen=True)
class Violation:
    level: str
    rule_id: str
    path: str
    message: str


@dataclass(frozen=True)
class Zone:
    id: str
    path_globs: tuple[str, ...]
    policy: str


@dataclass(frozen=True)
class OwnershipRule:
    id: str
    path_globs: tuple[str, ...]
    allowed_layers: tuple[str, ...]
    message: str


@dataclass(frozen=True)
class ContentRule:
    id: str
    pattern: str
    message: str
    layers: tuple[str, ...]
    path_globs: tuple[str, ...]
    regex: re.Pattern[str]


@dataclass(frozen=True)
class Exemption:
    id: str
    path_globs: tuple[str, ...]
    rule_globs: tuple[str, ...]
    reason: str
    owner: str
    ticket: str
    expires_on: dt.date | None


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Check machine-checkable architecture invariants.")
    parser.add_argument(
        "--config",
        default=".architecture-invariants.toml",
        help="Path to the architecture invariant TOML config.",
    )
    return parser.parse_args()


def ensure_list(value: object) -> list[str]:
    if value is None:
        return []
    if isinstance(value, list):
        return [str(item) for item in value]
    return [str(value)]


def path_matches(globs: list[str] | tuple[str, ...], rel_path: str) -> bool:
    return any(fnmatch.fnmatch(rel_path, pattern) for pattern in globs)


def normalize_level(level: str | None) -> str:
    if level is None:
        return "error"
    lowered = level.lower()
    if lowered not in {"error", "warn", "off"}:
        raise ValueError(f"unsupported level: {level}")
    return lowered


def load_config(config_path: pathlib.Path) -> dict:
    return parse_toml_subset(config_path.read_text(encoding="utf-8"))


def parse_toml_subset(text: str) -> dict:
    root: dict = {}
    current: dict = root

    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue

        if line.startswith("[[") and line.endswith("]]"):
            path = [part.strip() for part in line[2:-2].strip().split(".") if part.strip()]
            if not path:
                raise ValueError(f"invalid array table header: {raw_line}")
            current = ensure_array_table(root, path)
            continue

        if line.startswith("[") and line.endswith("]"):
            path = [part.strip() for part in line[1:-1].strip().split(".") if part.strip()]
            if not path:
                raise ValueError(f"invalid table header: {raw_line}")
            current = ensure_table(root, path)
            continue

        if "=" not in line:
            raise ValueError(f"invalid TOML line: {raw_line}")
        key, raw_value = line.split("=", 1)
        current[key.strip()] = parse_toml_value(raw_value.strip())

    return root


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


def parse_toml_value(raw_value: str) -> object:
    if raw_value.startswith('"') and raw_value.endswith('"'):
        return parse_basic_string(raw_value[1:-1])
    if raw_value.startswith("[") and raw_value.endswith("]"):
        inner = raw_value[1:-1].strip()
        if not inner:
            return []
        parts: list[str] = []
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
    if raw_value.isdigit():
        return int(raw_value)
    return raw_value


def parse_basic_string(value: str) -> str:
    result: list[str] = []
    index = 0
    escape_map = {
        "n": "\n",
        "r": "\r",
        "t": "\t",
        '"': '"',
        "\\": "\\",
    }

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


def gather_source_files(base_dir: pathlib.Path, source_cfg: dict) -> list[pathlib.Path]:
    roots = [base_dir / root for root in ensure_list(source_cfg.get("roots"))]
    extensions = {ext for ext in ensure_list(source_cfg.get("extensions")) if ext}
    files: list[pathlib.Path] = []
    seen: set[pathlib.Path] = set()

    for root in roots:
        if not root.exists():
            continue
        if root.is_file():
            candidates = [root]
        else:
            candidates = [path for path in root.rglob("*") if path.is_file()]
        for path in candidates:
            if extensions and path.suffix not in extensions:
                continue
            if path in seen:
                continue
            seen.add(path)
            files.append(path)

    return sorted(files)


def parse_zones(config: dict) -> list[Zone]:
    zones = []
    for item in config.get("zones", []):
        zones.append(
            Zone(
                id=str(item["id"]),
                path_globs=tuple(ensure_list(item.get("path_globs"))),
                policy=str(item.get("policy", "relaxed")),
            )
        )
    return zones


def parse_ownership_rules(config: dict) -> list[OwnershipRule]:
    rules = []
    for item in config.get("ownership_rules", []):
        rules.append(
            OwnershipRule(
                id=str(item["id"]),
                path_globs=tuple(ensure_list(item.get("path_globs"))),
                allowed_layers=tuple(ensure_list(item.get("allowed_layers"))),
                message=str(item["message"]),
            )
        )
    return rules


def parse_content_rules(config: dict) -> list[ContentRule]:
    rules = []
    for item in config.get("content_rules", []):
        pattern = str(item["pattern"])
        rules.append(
            ContentRule(
                id=str(item["id"]),
                pattern=pattern,
                message=str(item["message"]),
                layers=tuple(ensure_list(item.get("layers"))),
                path_globs=tuple(ensure_list(item.get("path_globs"))),
                regex=re.compile(pattern, re.MULTILINE),
            )
        )
    return rules


def parse_exemptions(config: dict) -> list[Exemption]:
    exemptions = []
    for item in config.get("exemptions", []):
        expires_on = item.get("expires_on")
        parsed_date = dt.date.fromisoformat(str(expires_on)) if expires_on else None
        exemptions.append(
            Exemption(
                id=str(item["id"]),
                path_globs=tuple(ensure_list(item.get("path_globs"))),
                rule_globs=tuple(ensure_list(item.get("rule_globs"))),
                reason=str(item.get("reason", "")),
                owner=str(item.get("owner", "")),
                ticket=str(item.get("ticket", "")),
                expires_on=parsed_date,
            )
        )
    return exemptions


def imports_from_text(text: str) -> list[str]:
    matches = re.findall(r"^\s*(?:@testable\s+)?import\s+([A-Za-z_][A-Za-z0-9_\.]*)", text, re.MULTILINE)
    return matches


def matching_zone(zones: list[Zone], rel_path: str) -> Zone | None:
    for zone in zones:
        if path_matches(zone.path_globs, rel_path):
            return zone
    return None


def classify_layer(layers_cfg: dict, rel_path: str) -> list[str]:
    matches = []
    for layer_name, layer_cfg in layers_cfg.items():
        if path_matches(ensure_list(layer_cfg.get("paths")), rel_path):
            matches.append(layer_name)
    return matches


def effective_level(category: str, mode_cfg: dict, zone: Zone | None) -> str:
    level = normalize_level(mode_cfg.get(category))
    if level == "off":
        return level
    if zone and zone.policy == "relaxed" and level == "error":
        return "warn"
    return level


def expired_exemption_violations(exemptions: list[Exemption], mode_cfg: dict) -> list[Violation]:
    level = normalize_level(mode_cfg.get("expired_exemptions"))
    if level == "off":
        return []

    today = dt.date.today()
    violations = []
    for exemption in exemptions:
        if exemption.expires_on is None or exemption.expires_on >= today:
            continue
        violations.append(
            Violation(
                level=level,
                rule_id=f"expired-exemption:{exemption.id}",
                path="<config>",
                message=(
                    f"Exemption '{exemption.id}' expired on {exemption.expires_on.isoformat()} "
                    f"and must be removed or renewed."
                ),
            )
        )
    return violations


def is_exempted(rel_path: str, rule_id: str, exemptions: list[Exemption]) -> bool:
    today = dt.date.today()
    for exemption in exemptions:
        if exemption.expires_on is not None and exemption.expires_on < today:
            continue
        if exemption.path_globs and not path_matches(exemption.path_globs, rel_path):
            continue
        if exemption.rule_globs and not any(fnmatch.fnmatch(rule_id, pattern) for pattern in exemption.rule_globs):
            continue
        return True
    return False


def add_violation(
    violations: list[Violation],
    exemptions: list[Exemption],
    rel_path: str,
    level: str,
    rule_id: str,
    message: str,
) -> None:
    if level == "off":
        return
    if is_exempted(rel_path, rule_id, exemptions):
        return
    violations.append(Violation(level=level, rule_id=rule_id, path=rel_path, message=message))


def main() -> int:
    args = parse_args()
    config_path = pathlib.Path(args.config).resolve()
    if not config_path.exists():
        print(f"missing config: {config_path}", file=sys.stderr)
        return 1

    config = load_config(config_path)
    base_dir = config_path.parent
    source_cfg = config.get("source", {})
    mode_cfg = config.get("mode", {})
    layers_cfg = config.get("layers", {})
    zones = parse_zones(config)
    ownership_rules = parse_ownership_rules(config)
    content_rules = parse_content_rules(config)
    exemptions = parse_exemptions(config)

    violations = expired_exemption_violations(exemptions, mode_cfg)
    files = gather_source_files(base_dir, source_cfg)

    if not files:
        if violations:
            for violation in violations:
                print(f"{violation.level.upper()} {violation.path} {violation.rule_id}: {violation.message}")
            return 1
        print(f"architecture invariants skipped: no matching source files found for {config_path.name}")
        return 0

    for file_path in files:
        rel_path = file_path.relative_to(base_dir).as_posix()
        zone = matching_zone(zones, rel_path)
        if zone and zone.policy == "skip":
            continue

        layer_matches = classify_layer(layers_cfg, rel_path)
        if len(layer_matches) > 1:
            add_violation(
                violations,
                exemptions,
                rel_path,
                effective_level("multi_layer_match", mode_cfg, zone),
                "layer-classification:multiple",
                f"File matched multiple layers: {', '.join(layer_matches)}",
            )
            layer = None
        elif len(layer_matches) == 1:
            layer = layer_matches[0]
        else:
            layer = None
            add_violation(
                violations,
                exemptions,
                rel_path,
                effective_level("unknown_paths", mode_cfg, zone),
                "layer-classification:unknown",
                "File did not match any declared architecture layer.",
            )

        text = file_path.read_text(encoding="utf-8")
        imports = imports_from_text(text)

        if layer is not None:
            for prefix in ensure_list(layers_cfg[layer].get("forbidden_import_prefixes")):
                for imported_module in imports:
                    if imported_module == prefix or imported_module.startswith(f"{prefix}."):
                        add_violation(
                            violations,
                            exemptions,
                            rel_path,
                            effective_level("forbidden_imports", mode_cfg, zone),
                            f"forbidden-import:{layer}:{prefix}",
                            f"Layer '{layer}' must not import '{imported_module}'.",
                        )

        for rule in ownership_rules:
            if not path_matches(rule.path_globs, rel_path):
                continue
            if layer is None or layer not in rule.allowed_layers:
                allowed = ", ".join(rule.allowed_layers)
                add_violation(
                    violations,
                    exemptions,
                    rel_path,
                    effective_level("ownership", mode_cfg, zone),
                    f"ownership:{rule.id}",
                    f"{rule.message} Allowed layers: {allowed}.",
                )

        for rule in content_rules:
            if rule.layers and (layer is None or layer not in rule.layers):
                continue
            if rule.path_globs and not path_matches(rule.path_globs, rel_path):
                continue
            if not rule.regex.search(text):
                continue
            add_violation(
                violations,
                exemptions,
                rel_path,
                effective_level("forbidden_content", mode_cfg, zone),
                f"forbidden-content:{rule.id}",
                rule.message,
            )

    error_count = sum(1 for item in violations if item.level == "error")
    warn_count = sum(1 for item in violations if item.level == "warn")

    for violation in sorted(violations, key=lambda item: (item.path, item.rule_id, item.message)):
        print(f"{violation.level.upper()} {violation.path} {violation.rule_id}: {violation.message}")

    if error_count:
        print(f"architecture invariants failed: {error_count} error(s), {warn_count} warning(s)", file=sys.stderr)
        return 1

    if warn_count:
        print(f"architecture invariants passed with warnings: {warn_count}", file=sys.stderr)
    else:
        print(f"architecture invariants passed: {len(files)} file(s) checked")
    return 0


if __name__ == "__main__":
    sys.exit(main())
