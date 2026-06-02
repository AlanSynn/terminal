#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/log.sh
. "$ROOT_DIR/scripts/lib/log.sh"

command -v chezmoi >/dev/null 2>&1 || die "chezmoi is required for terminal parity checks"

DIFF_FILE="$(mktemp "${TMPDIR:-/tmp}/workstation-terminal-parity.XXXXXX.diff")"
trap 'rm -f "$DIFF_FILE"' EXIT

failures=0
compare_rendered() {
  local source_rel="$1" dest="$2"
  if [[ ! -f "$dest" ]]; then
    error "terminal target missing: $dest"
    failures=$((failures + 1))
    return 0
  fi
  if ! chezmoi execute-template -S "$ROOT_DIR" -f "$ROOT_DIR/$source_rel" | diff -u "$dest" - >"$DIFF_FILE"; then
    error "terminal parity mismatch: $source_rel -> $dest"
    cat "$DIFF_FILE"
    failures=$((failures + 1))
  fi
}

compare_plain() {
  local source_rel="$1" dest="$2"
  if [[ ! -f "$dest" ]]; then
    error "terminal target missing: $dest"
    failures=$((failures + 1))
    return 0
  fi
  if ! diff -u "$dest" "$ROOT_DIR/$source_rel" >"$DIFF_FILE"; then
    error "terminal parity mismatch: $source_rel -> $dest"
    cat "$DIFF_FILE"
    failures=$((failures + 1))
  fi
}

compare_rendered "dot_zshrc.tmpl" "$HOME/.zshrc"
compare_rendered "dot_zshrc.alan.tmpl" "$HOME/.zshrc.alan"
compare_rendered "private_dot_ssh/config.tmpl" "$HOME/.ssh/config"
compare_rendered "private_dot_gnupg/gpg-agent.conf.tmpl" "$HOME/.gnupg/gpg-agent.conf"

compare_plain "dot_shell.alan" "$HOME/.shell.alan"
compare_plain "dot_tmux.conf" "$HOME/.tmux.conf"
compare_plain "dot_tmux.conf.local" "$HOME/.tmux.conf.local"
compare_plain "dot_gitconfig" "$HOME/.gitconfig"
compare_plain "dot_gitignore" "$HOME/.gitignore"
compare_plain "dot_condarc" "$HOME/.condarc"
compare_plain "dot_clang-format" "$HOME/.clang-format"
compare_plain "private_dot_config/git/ignore" "$HOME/.config/git/ignore"
compare_plain "dot_vimrc" "$HOME/.vimrc"
compare_plain "dot_fzf.zsh" "$HOME/.fzf.zsh"
compare_plain "private_dot_local/bin/env" "$HOME/.local/bin/env"
compare_plain "private_dot_ssh/configs/personal/aws" "$HOME/.ssh/configs/personal/aws"
compare_plain "private_dot_ssh/configs/gatech/nersc" "$HOME/.ssh/configs/gatech/nersc"
compare_plain "private_dot_ssh/configs/gatech/gatech" "$HOME/.ssh/configs/gatech/gatech"

if [[ "$failures" -gt 0 ]]; then
  die "terminal parity failed with $failures mismatch(es)"
fi
success "terminal parity checks passed"
