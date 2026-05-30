#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/log.sh
. "$ROOT_DIR/scripts/lib/log.sh"

inventory_dir="$ROOT_DIR/inventories/current-machine"
report="$inventory_dir/curation-report.md"
mkdir -p "$inventory_dir"

tmp_dir="$(mktemp -d)"
cleanup() { rm -rf "$tmp_dir"; }
trap cleanup EXIT

sort_file() {
  local input="$1" output="$2"
  if [[ -f "$input" ]]; then
    { grep -Ev '^[[:space:]]*(#|$)' "$input" || true; } | LC_ALL=C sort -u > "$output"
  else
    : > "$output"
  fi
}

extract_brewfile_kind() {
  local kind="$1" output="$2"
  shift 2
  : > "$output"
  local file
  for file in "$@"; do
    [[ -f "$file" ]] || continue
    sed -n "s/^[[:space:]]*$kind[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$file" >> "$output"
  done
  LC_ALL=C sort -u -o "$output" "$output"
}

extract_first_column_manifest() {
  local input="$1" output="$2"
  if [[ -f "$input" ]]; then
    { grep -Ev '^[[:space:]]*(#|$)' "$input" || true; } | awk '{print $1}' | LC_ALL=C sort -u > "$output"
  else
    : > "$output"
  fi
}

write_delta() {
  local title="$1" current="$2" manifest="$3"
  local missing="$tmp_dir/missing" extra="$tmp_dir/extra"
  comm -23 "$current" "$manifest" > "$missing"
  comm -13 "$current" "$manifest" > "$extra"
  printf '## %s\n\n' "$title" >> "$report"
  printf -- '- Current inventory entries: %s\n' "$(wc -l < "$current" | tr -d ' ')" >> "$report"
  printf -- '- Manifest entries: %s\n' "$(wc -l < "$manifest" | tr -d ' ')" >> "$report"
  printf -- '- In inventory, not manifest: %s\n' "$(wc -l < "$missing" | tr -d ' ')" >> "$report"
  printf -- '- In manifest, not inventory: %s\n\n' "$(wc -l < "$extra" | tr -d ' ')" >> "$report"
  if [[ -s "$missing" ]]; then
    printf '<details><summary>Inventory-only candidates</summary>\n\n```text\n' >> "$report"
    sed -n '1,200p' "$missing" >> "$report"
    printf '```\n\n</details>\n\n' >> "$report"
  fi
  if [[ -s "$extra" ]]; then
    printf '<details><summary>Manifest-only entries</summary>\n\n```text\n' >> "$report"
    sed -n '1,200p' "$extra" >> "$report"
    printf '```\n\n</details>\n\n' >> "$report"
  fi
}

sort_file "$inventory_dir/brew-leaves.txt" "$tmp_dir/current-brew"
extract_brewfile_kind brew "$tmp_dir/manifest-brew" \
  "$ROOT_DIR/packages/Brewfile.common" \
  "$ROOT_DIR/packages/Brewfile.darwin" \
  "$ROOT_DIR/packages/Brewfile.linux"

sort_file "$inventory_dir/brew-casks.txt" "$tmp_dir/current-cask"
extract_brewfile_kind cask "$tmp_dir/manifest-cask" "$ROOT_DIR/packages/Brewfile.darwin"

extract_first_column_manifest "$inventory_dir/mas-list.txt" "$tmp_dir/current-mas"
extract_first_column_manifest "$ROOT_DIR/packages/mas.darwin.txt" "$tmp_dir/manifest-mas"

sort_file "$inventory_dir/vscode-extensions.txt" "$tmp_dir/current-vscode"
sort_file "$ROOT_DIR/packages/vscode-extensions.txt" "$tmp_dir/manifest-vscode"

sort_file "$inventory_dir/npm-global.txt" "$tmp_dir/current-npm"
sort_file "$ROOT_DIR/packages/npm-global.txt" "$tmp_dir/manifest-npm"

sort_file "$inventory_dir/bun-global.txt" "$tmp_dir/current-bun"
sort_file "$ROOT_DIR/packages/bun-global.txt" "$tmp_dir/manifest-bun"

sort_file "$inventory_dir/uv-tools.txt" "$tmp_dir/current-uv"
sort_file "$ROOT_DIR/packages/uv-tools.txt" "$tmp_dir/manifest-uv"

sort_file "$inventory_dir/cargo-tools.txt" "$tmp_dir/current-cargo"
sort_file "$ROOT_DIR/packages/cargo-tools.txt" "$tmp_dir/manifest-cargo"

{
  printf '# Inventory Curation Report\n\n'
  printf 'This report compares names-only current-machine inventory files against curated package manifests. Inventory-only entries are review candidates, not automatic additions.\n\n'
} > "$report"

write_delta "Homebrew formulae" "$tmp_dir/current-brew" "$tmp_dir/manifest-brew"
write_delta "Homebrew casks" "$tmp_dir/current-cask" "$tmp_dir/manifest-cask"
write_delta "Mac App Store apps" "$tmp_dir/current-mas" "$tmp_dir/manifest-mas"
write_delta "VS Code extensions" "$tmp_dir/current-vscode" "$tmp_dir/manifest-vscode"
write_delta "npm globals" "$tmp_dir/current-npm" "$tmp_dir/manifest-npm"
write_delta "bun globals" "$tmp_dir/current-bun" "$tmp_dir/manifest-bun"
write_delta "uv tools" "$tmp_dir/current-uv" "$tmp_dir/manifest-uv"
write_delta "cargo tools" "$tmp_dir/current-cargo" "$tmp_dir/manifest-cargo"

python3 - "$report" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
p.write_text(p.read_text().rstrip() + "\n")
PY

success "wrote $report"
