#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/log.sh
. "$ROOT_DIR/scripts/lib/log.sh"
# shellcheck source=scripts/lib/os.sh
. "$ROOT_DIR/scripts/lib/os.sh"

is_linux || { warn "not Linux; skipping Linux defaults"; exit 0; }

info "Applying conservative Linux defaults"
run_or_echo mkdir -p "$HOME/bin" "$HOME/.local/bin" "$HOME/.config"
if command -v zsh >/dev/null 2>&1; then
  info "zsh present: $(command -v zsh)"
else
  warn "zsh missing; install native prerequisites first"
fi
success "Linux defaults complete"
