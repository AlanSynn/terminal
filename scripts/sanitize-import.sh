#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/log.sh
. "$ROOT_DIR/scripts/lib/log.sh"
# shellcheck source=scripts/lib/secrets.sh
. "$ROOT_DIR/scripts/lib/secrets.sh"

SRC=""
MODE="dry-run"
FORCE=0

usage() {
  cat <<USAGE
Usage: scripts/sanitize-import.sh --from PATH [--dry-run|--apply] [--force]

Allowlist-copy safe dotfile material from the old Init repo. Default is dry-run.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --from) SRC="${2:?missing source path}"; shift 2 ;;
    --dry-run) MODE="dry-run"; shift ;;
    --apply) MODE="apply"; shift ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ -n "$SRC" ]] || die "--from PATH is required"
[[ -d "$SRC" ]] || die "source does not exist: $SRC"
SRC="$(cd "$SRC" && pwd)"

allowed_exact=(
  .chezmoiexternal.toml
  dot_clang-format
  dot_condarc
  dot_gitignore
  dot_tmux.conf
  dot_vimrc
  private_dot_config/git/ignore
  private_dot_ssh/config.tmpl
)
allowed_prefix=(
  private_dot_config/opencode/
  private_dot_config/llm/
  private_dot_config/zed/
)

is_allowed_import_path() {
  local rel="$1" exact prefix
  for exact in "${allowed_exact[@]}"; do
    [[ "$rel" == "$exact" ]] && return 0
  done
  for prefix in "${allowed_prefix[@]}"; do
    [[ "$rel" == "$prefix"* ]] && return 0
  done
  return 1
}

copied=0
skipped=0
blocked=0

while IFS= read -r -d '' file; do
  rel="${file#"$SRC/"}"
  rel="$(normalize_relpath "$rel")"

  if ! is_allowed_import_path "$rel"; then
    continue
  fi
  if is_runtime_path "$rel" || is_forbidden_secret_path "$rel"; then
    warn "blocked path: $rel"
    blocked=$((blocked + 1))
    continue
  fi
  if reason="$(secret_reason "$file")"; then
    warn "blocked content ($reason): $rel"
    blocked=$((blocked + 1))
    continue
  fi

  dest="$ROOT_DIR/$rel"
  if [[ -e "$dest" && "$FORCE" != "1" ]]; then
    info "skip existing: $rel"
    skipped=$((skipped + 1))
    continue
  fi

  if [[ "$MODE" == "dry-run" ]]; then
    info "would copy: $rel"
  else
    mkdir -p "$(dirname "$dest")"
    cp -p "$file" "$dest"
    info "copied: $rel"
  fi
  copied=$((copied + 1))
done < <(find "$SRC" -type f -print0)

info "sanitize-import mode=$MODE source=$SRC copied_or_planned=$copied skipped_existing=$skipped blocked=$blocked"
if [[ "$blocked" -gt 0 ]]; then
  warn "blocked files were not imported; inspect output before using --force or widening allowlist"
fi
