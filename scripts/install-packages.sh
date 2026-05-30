#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/log.sh
. "$ROOT_DIR/scripts/lib/log.sh"
# shellcheck source=scripts/lib/os.sh
. "$ROOT_DIR/scripts/lib/os.sh"

TIER="${BOOTSTRAP_TIER:-minimal}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tier) TIER="${2:?missing tier}"; shift 2 ;;
    *) die "unknown argument: $1" ;;
  esac
done

run_brew_bundle() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  if ! command -v brew >/dev/null 2>&1; then
    warn "brew unavailable; skipping $file"
    return 0
  fi
  run_or_echo brew bundle --file "$file"
}

install_mas_apps() {
  local file="$ROOT_DIR/packages/mas.darwin.txt"
  [[ -f "$file" ]] || return 0
  command -v mas >/dev/null 2>&1 || { warn "mas unavailable; skipping App Store apps"; return 0; }
  if ! is_dry_run && ! mas account >/dev/null 2>&1; then
    warn "mas is not signed in; skipping App Store apps"
    return 0
  fi
  while read -r app_id _name; do
    [[ -n "$app_id" ]] || continue
    [[ "$app_id" =~ ^# ]] && continue
    run_or_echo mas install "$app_id" || warn "mas install failed/non-fatal: $app_id"
  done < "$file"
}

load_homebrew_env || true
info "install package manifests tier=$TIER"

case "$TIER" in
  minimal|ci)
    run_brew_bundle "$ROOT_DIR/packages/Brewfile.common"
    ;;
  cli)
    run_brew_bundle "$ROOT_DIR/packages/Brewfile.common"
    if is_linux; then
      run_brew_bundle "$ROOT_DIR/packages/Brewfile.linux"
    fi
    ;;
  full)
    run_brew_bundle "$ROOT_DIR/packages/Brewfile.common"
    if is_macos; then
      run_brew_bundle "$ROOT_DIR/packages/Brewfile.darwin"
      install_mas_apps
    elif is_linux; then
      run_brew_bundle "$ROOT_DIR/packages/Brewfile.linux"
    fi
    ;;
  *)
    die "unsupported tier: $TIER"
    ;;
esac
