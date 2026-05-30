#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/log.sh
. "$ROOT_DIR/scripts/lib/log.sh"
# shellcheck source=scripts/lib/os.sh
. "$ROOT_DIR/scripts/lib/os.sh"

out_dir="$ROOT_DIR/inventories/current-machine"
mkdir -p "$out_dir"

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

capture uname.txt uname -a
if is_macos && command -v sw_vers >/dev/null 2>&1; then capture sw_vers.txt sw_vers; fi
if is_linux && [[ -r /etc/os-release ]]; then cp /etc/os-release "$out_dir/os-release.txt"; fi

if command -v brew >/dev/null 2>&1; then
  capture brew-leaves.txt brew leaves
  capture brew-casks.txt brew list --cask
  capture brew-taps.txt brew tap
  capture brew-bundle-dump.txt brew bundle dump --describe --force --file -
fi
if command -v mas >/dev/null 2>&1; then capture mas-list.txt mas list; fi
if command -v code >/dev/null 2>&1; then capture vscode-extensions.txt code --list-extensions; fi
if command -v npm >/dev/null 2>&1; then capture npm-global.txt npm ls -g --depth=0 --parseable; fi
if command -v bun >/dev/null 2>&1; then capture bun-global.txt bun pm ls -g; fi
if command -v uv >/dev/null 2>&1; then capture uv-tools.txt uv tool list; fi
if command -v cargo >/dev/null 2>&1; then capture cargo-tools.txt cargo install --list; fi

cat > "$out_dir/sensitive-paths-redacted.txt" <<'REDACTED'
Credentials, tokens, keychains, browser profiles, cloud auth caches, private SSH/GPG keys, and opaque app state are intentionally not inventoried into git.
REDACTED
success "audit complete: $out_dir"
