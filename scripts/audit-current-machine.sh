#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/log.sh
. "$ROOT_DIR/scripts/lib/log.sh"
# shellcheck source=scripts/lib/os.sh
. "$ROOT_DIR/scripts/lib/os.sh"

out_dir="$ROOT_DIR/inventories/current-machine"
raw_dir="$out_dir/raw"
mkdir -p "$out_dir" "$raw_dir"

write_sorted() {
  local name="$1"; shift
  local file="$out_dir/$name"
  if "$@" | sed '/^[[:space:]]*$/d' | LC_ALL=C sort -u > "$file" 2>/dev/null; then
    success "wrote $file"
  else
    : > "$file"
    warn "could not capture $name"
  fi
}

capture() {
  local name="$1"; shift
  local file="$out_dir/$name"
  if "$@" > "$file" 2>/dev/null; then
    success "wrote $file"
  else
    : > "$file"
    warn "could not capture $name"
  fi
}

capture_raw() {
  local name="$1"; shift
  local file="$raw_dir/$name"
  if "$@" > "$file" 2>/dev/null; then
    success "wrote raw/$name (ignored by git)"
  else
    : > "$file"
    warn "could not capture raw/$name"
  fi
}

{
  printf 'kernel=%s\n' "$(uname -s)"
  printf 'kernel_release=%s\n' "$(uname -r)"
  printf 'machine=%s\n' "$(uname -m)"
} > "$out_dir/uname.txt"
success "wrote $out_dir/uname.txt"
if is_macos && command -v sw_vers >/dev/null 2>&1; then capture sw_vers.txt sw_vers; fi
if is_linux && [[ -r /etc/os-release ]]; then cp /etc/os-release "$out_dir/os-release.txt"; fi

if command -v brew >/dev/null 2>&1; then
  write_sorted brew-leaves.txt brew leaves
  write_sorted brew-casks.txt brew list --cask
  write_sorted brew-taps.txt brew tap
  capture_raw brew-bundle-dump.txt brew bundle dump --describe --force --file -
fi

if command -v mas >/dev/null 2>&1; then
  mas list 2>/dev/null | sed -E 's/[[:space:]]+\([^)]*\)$//' | sed '/^[[:space:]]*$/d' | LC_ALL=C sort -u > "$out_dir/mas-list.txt" || : > "$out_dir/mas-list.txt"
  success "wrote $out_dir/mas-list.txt"
fi

if command -v code >/dev/null 2>&1; then
  write_sorted vscode-extensions.txt code --list-extensions
fi

if command -v npm >/dev/null 2>&1; then
  if command -v node >/dev/null 2>&1; then
    npm ls -g --depth=0 --json 2>/dev/null \
      | node -e 'let s=""; process.stdin.on("data", d => s += d); process.stdin.on("end", () => { const j = JSON.parse(s || "{}"); for (const k of Object.keys(j.dependencies || {}).sort()) console.log(k); });' \
      > "$out_dir/npm-global.txt" || : > "$out_dir/npm-global.txt"
  else
    npm ls -g --depth=0 --parseable 2>/dev/null \
      | sed '1d; s#.*/##' \
      | sed '/^[[:space:]]*$/d' \
      | LC_ALL=C sort -u > "$out_dir/npm-global.txt" || : > "$out_dir/npm-global.txt"
  fi
  success "wrote $out_dir/npm-global.txt"
fi

if command -v bun >/dev/null 2>&1; then
  capture_raw bun-pm-ls-g.txt bun pm ls -g
  bun pm ls -g 2>/dev/null \
    | sed -n 's/^[[:space:]]*[├└│─ ]*//; /^[(@A-Za-z0-9_.-]/p' \
    | awk '{print $1}' \
    | sed 's/@[0-9][^[:space:]]*$//; /^$/d' \
    | LC_ALL=C sort -u > "$out_dir/bun-global.txt" || : > "$out_dir/bun-global.txt"
  success "wrote $out_dir/bun-global.txt"
fi

if command -v uv >/dev/null 2>&1; then
  uv tool list 2>/dev/null \
    | awk '/^[A-Za-z0-9_.][A-Za-z0-9_.-]*[[:space:]]/ {print $1}' \
    | LC_ALL=C sort -u > "$out_dir/uv-tools.txt" || : > "$out_dir/uv-tools.txt"
  success "wrote $out_dir/uv-tools.txt"
fi

if command -v cargo >/dev/null 2>&1; then
  cargo install --list 2>/dev/null \
    | awk '/^[^[:space:]].*:$/ {name=$1; sub(/ .*/, "", name); sub(/:$/, "", name); print name}' \
    | LC_ALL=C sort -u > "$out_dir/cargo-tools.txt" || : > "$out_dir/cargo-tools.txt"
  success "wrote $out_dir/cargo-tools.txt"
fi

cat > "$out_dir/sensitive-paths-redacted.txt" <<'REDACTED'
Credentials, tokens, keychains, browser profiles, cloud auth caches, private SSH/GPG keys, and opaque app state are intentionally not inventoried into git.
REDACTED

cat > "$out_dir/README.md" <<'README'
# Current Machine Inventory

This directory contains names-only or explicitly redacted outputs from `scripts/audit-current-machine.sh`.

Tracked files are intended as review inputs for package manifest curation. Raw command dumps are written under `raw/`, which is git-ignored and skipped by the secret scanner.
README

{
  printf '# Current Machine Summary\n\n'
  printf -- '- OS: %s\n' "$(detect_os)"
  printf -- '- Architecture: %s\n' "$(detect_arch)"
  if is_linux; then printf -- '- Linux ID: %s\n' "$(linux_id)"; fi
  for file in brew-leaves.txt brew-casks.txt mas-list.txt vscode-extensions.txt npm-global.txt bun-global.txt uv-tools.txt cargo-tools.txt; do
    if [[ -f "$out_dir/$file" ]]; then
      printf -- '- %s: %s entries\n' "$file" "$(grep -cve '^[[:space:]]*$' "$out_dir/$file" || true)"
    fi
  done
} > "$out_dir/machine-summary.md"
success "wrote $out_dir/machine-summary.md"

success "audit complete: $out_dir"
