#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/log.sh
. "$ROOT_DIR/scripts/lib/log.sh"

active_lines() {
  grep -Ev '^[[:space:]]*(#|$)' "$1" || true
}

check_no_duplicates() {
  local label="$1" file="$2"
  local dupes
  dupes="$(active_lines "$file" | LC_ALL=C sort | uniq -d)"
  [[ -z "$dupes" ]] || die "$label contains duplicate entries: $dupes"
}

check_sorted_unique() {
  local label="$1" file="$2" tmp
  tmp="$(mktemp)"
  active_lines "$file" > "$tmp"
  if ! LC_ALL=C sort -c "$tmp" >/dev/null 2>&1; then
    rm -f "$tmp"
    die "$label must be sorted for stable reviews"
  fi
  rm -f "$tmp"
}

check_no_duplicates "VS Code manifest" "$ROOT_DIR/packages/vscode-extensions.txt"
check_sorted_unique "VS Code manifest" "$ROOT_DIR/packages/vscode-extensions.txt"

if ! active_lines "$ROOT_DIR/packages/vscode-extensions.txt" | awk '$0 !~ /^[a-z0-9][a-z0-9-]*\.[a-z0-9][a-z0-9-]*$/ { print; bad=1 } END { exit bad }'; then
  die "VS Code manifest contains malformed extension IDs"
fi

missing_vscode="$(comm -23 \
  <(active_lines "$ROOT_DIR/packages/vscode-extensions.txt" | LC_ALL=C sort -u) \
  <(active_lines "$ROOT_DIR/inventories/current-machine/vscode-extensions.txt" | LC_ALL=C sort -u))"
[[ -z "$missing_vscode" ]] || die "VS Code manifest has entries not present in reviewed inventory: $missing_vscode"

if [[ "$(active_lines "$ROOT_DIR/packages/vscode-extensions.txt" | wc -l | tr -d ' ')" -eq 0 ]]; then
  die "VS Code manifest is empty"
fi

if ! active_lines "$ROOT_DIR/packages/mas.darwin.txt" | awk '$1 !~ /^[0-9]+$/ || NF < 2 { print; bad=1 } END { exit bad }'; then
  die "MAS manifest contains malformed lines"
fi

mas_dupes="$(active_lines "$ROOT_DIR/packages/mas.darwin.txt" | awk '{print $1}' | LC_ALL=C sort | uniq -d)"
[[ -z "$mas_dupes" ]] || die "MAS manifest contains duplicate app IDs: $mas_dupes"

missing_mas="$(comm -23 \
  <(active_lines "$ROOT_DIR/packages/mas.darwin.txt" | awk '{print $1}' | LC_ALL=C sort -u) \
  <(active_lines "$ROOT_DIR/inventories/current-machine/mas-list.txt" | awk '{print $1}' | LC_ALL=C sort -u))"
[[ -z "$missing_mas" ]] || die "MAS manifest has app IDs not present in reviewed inventory: $missing_mas"

python3 - "$ROOT_DIR/backup/user-dirs.json" "$ROOT_DIR/backup/excludes" <<'PY'
import json, pathlib, sys
manifest = pathlib.Path(sys.argv[1])
exclude_dir = pathlib.Path(sys.argv[2])
data = json.loads(manifest.read_text())
assert data["tool"] == "rsync"
assert data["defaultDelete"] is False
ids = set()
for item in data["sets"]:
    assert item["id"] not in ids, item["id"]
    ids.add(item["id"])
    assert not item["dest"].startswith("/"), item
    assert ".." not in pathlib.PurePosixPath(item["dest"]).parts, item
    assert item["platforms"], item
    for exclude in item.get("excludeFiles", []):
        assert (exclude_dir / exclude).is_file(), exclude
PY

success "manifest consistency checks passed"
