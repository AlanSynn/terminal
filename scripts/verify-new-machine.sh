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

info "verify workstation-bootstrap tier=$TIER"

required_files=(
  masterplan.md
  README.md
  bootstrap.sh
  Justfile
  .chezmoi.toml.tmpl
  .chezmoiignore
  packages/Brewfile.common
  scripts/doctor.sh
  scripts/sanitize-import.sh
  scripts/curate-inventory.sh
  scripts/verify-no-secrets.sh
)
for rel in "${required_files[@]}"; do
  [[ -f "$ROOT_DIR/$rel" ]] || die "missing required file: $rel"
done

"$ROOT_DIR/scripts/doctor.sh"
"$ROOT_DIR/scripts/verify-no-secrets.sh"

shopt -s nullglob
shell_files=("$ROOT_DIR/bootstrap.sh" "$ROOT_DIR"/scripts/*.sh "$ROOT_DIR"/scripts/lib/*.sh "$ROOT_DIR"/test/*.sh)
bash -n "${shell_files[@]}"
success "shell syntax passes"

if command -v just >/dev/null 2>&1; then
  (cd "$ROOT_DIR" && just --list >/dev/null)
  success "just recipes parse"
else
  warn "just unavailable; skipping Justfile parse"
fi

if command -v chezmoi >/dev/null 2>&1; then
  (cd "$ROOT_DIR" && chezmoi data --source "$ROOT_DIR" >/dev/null)
  success "chezmoi data renders"
  diff_log="${TMPDIR:-/tmp}/workstation-bootstrap-chezmoi-diff.$$"
  (cd "$ROOT_DIR" && chezmoi diff --source "$ROOT_DIR" > "$diff_log")
  rm -f "$diff_log"
  success "chezmoi diff renders"
else
  warn "chezmoi unavailable; skipping template render check"
fi

if command -v brew >/dev/null 2>&1; then
  brew bundle check --file "$ROOT_DIR/packages/Brewfile.common" >/dev/null 2>&1 || warn "brew common bundle is not fully installed yet"
fi

success "verification complete"
