#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/log.sh
. "$ROOT_DIR/scripts/lib/log.sh"
# shellcheck source=scripts/lib/os.sh
. "$ROOT_DIR/scripts/lib/os.sh"

info "workstation-bootstrap doctor"
info "repo=$ROOT_DIR"
info "os=$(detect_os) arch=$(detect_arch)"
if is_linux; then
  info "linux_id=$(linux_id) package_manager=$(package_manager)"
fi
if is_macos && command -v sw_vers >/dev/null 2>&1; then
  sw_vers | sed 's/^/[macos] /'
fi

check_cmd() {
  local cmd="$1" required="${2:-optional}"
  if command -v "$cmd" >/dev/null 2>&1; then
    success "$cmd: $(command -v "$cmd")"
  elif [[ "$required" == "required" ]]; then
    warn "$cmd: missing (required after bootstrap)"
  else
    warn "$cmd: missing (optional)"
  fi
}

check_cmd git required
check_cmd bash required
check_cmd curl required
check_cmd chezmoi required
check_cmd just optional
check_cmd brew optional
check_cmd mas optional
check_cmd op optional
check_cmd shellcheck optional
check_cmd docker optional

if brew_bin="$(find_brew 2>/dev/null)"; then
  info "brew_prefix=$("$brew_bin" --prefix 2>/dev/null || true)"
fi

success "doctor complete"
