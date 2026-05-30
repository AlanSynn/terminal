#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/log.sh
. "$ROOT_DIR/scripts/lib/log.sh"
# shellcheck source=scripts/lib/os.sh
. "$ROOT_DIR/scripts/lib/os.sh"

if brew_bin="$(find_brew 2>/dev/null)"; then
  success "Homebrew present: $brew_bin"
  eval "$("$brew_bin" shellenv)"
  info "brew_prefix=$(brew --prefix)"
  exit 0
fi

if ! is_macos && ! is_linux; then
  warn "Homebrew install unsupported on OS $(detect_os)"
  exit 0
fi

install_url="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
if is_dry_run; then
  info "Homebrew missing"
  printf '[dry-run] NONINTERACTIVE=1 bash -c "$(curl -fsSL %s)"\n' "$install_url"
  exit 0
fi

info "Installing Homebrew/Linuxbrew"
NONINTERACTIVE=1 bash -c "$(curl -fsSL "$install_url")"
if load_homebrew_env; then
  success "Homebrew installed: $(brew --prefix)"
else
  die "Homebrew install finished but brew is still not discoverable"
fi
