#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
tmp_file=$(mktemp)
trap 'rm -f "$tmp_file"' EXIT

find "$repo_root" -type f -name '*.md' | sort > "$tmp_file"

checked=0
missing=0

while IFS= read -r file; do
  dir=$(dirname "$file")
  links=$(perl -ne 'while (/\[[^][]*\]\(((?:\.\.?\/)[^#)]+)(?:#[^)]+)?\)/g) { print "$1\n"; }' "$file")

  if [ -z "$links" ]; then
    continue
  fi

  for link in $links; do
    checked=$((checked + 1))
    if [ ! -e "$dir/$link" ]; then
      echo "missing relative link target in $file: $link" >&2
      missing=$((missing + 1))
    fi
  done
done < "$tmp_file"

echo "checked $checked relative markdown links"

if [ "$missing" -ne 0 ]; then
  exit 1
fi
