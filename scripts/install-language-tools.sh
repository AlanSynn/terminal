#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/log.sh
. "$ROOT_DIR/scripts/lib/log.sh"

TIER="${BOOTSTRAP_TIER:-minimal}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tier) TIER="${2:?missing tier}"; shift 2 ;;
    *) die "unknown argument: $1" ;;
  esac
done

read_manifest() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  grep -Ev '^[[:space:]]*(#|$)' "$file"
}

install_lines() {
  local command_name="$1" manifest="$2" package
  [[ -f "$manifest" ]] || return 0
  if ! command -v "$command_name" >/dev/null 2>&1; then
    warn "$command_name unavailable; skipping $(basename "$manifest")"
    return 0
  fi
  while IFS= read -r package; do
    [[ -n "$package" ]] || continue
    case "$command_name" in
      npm) run_or_echo npm install -g "$package" ;;
      bun) run_or_echo bun add -g "$package" ;;
      uv) run_or_echo uv tool install "$package" ;;
      cargo) run_or_echo cargo install "$package" ;;
      *) die "unsupported language installer: $command_name" ;;
    esac
  done < <(read_manifest "$manifest")
}

case "$TIER" in
  minimal)
    info "tier=minimal; skipping language tools"
    exit 0
    ;;
  cli|full|ci)
    ;;
  *) die "unsupported tier: $TIER" ;;
esac

install_lines npm "$ROOT_DIR/packages/npm-global.txt"
install_lines bun "$ROOT_DIR/packages/bun-global.txt"
install_lines uv "$ROOT_DIR/packages/uv-tools.txt"
install_lines cargo "$ROOT_DIR/packages/cargo-tools.txt"
success "language tool manifest processing complete"
