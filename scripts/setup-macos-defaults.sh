#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/log.sh
. "$ROOT_DIR/scripts/lib/log.sh"
# shellcheck source=scripts/lib/os.sh
. "$ROOT_DIR/scripts/lib/os.sh"

is_macos || { warn "not macOS; skipping macOS defaults"; exit 0; }

info "Applying conservative macOS defaults"
run_or_echo defaults write NSGlobalDomain AppleShowAllExtensions -bool true
run_or_echo defaults write NSGlobalDomain InitialKeyRepeat -int 15
run_or_echo defaults write NSGlobalDomain KeyRepeat -int 2
run_or_echo defaults write com.apple.finder AppleShowAllFiles -bool true
run_or_echo defaults write com.apple.finder ShowPathbar -bool true
run_or_echo defaults write com.apple.finder ShowStatusBar -bool true
run_or_echo defaults write com.apple.dock autohide -bool true
run_or_echo defaults write com.apple.screencapture location -string "$HOME/Desktop"

if ! is_dry_run; then
  killall Finder >/dev/null 2>&1 || true
  killall Dock >/dev/null 2>&1 || true
fi
success "macOS defaults complete"
