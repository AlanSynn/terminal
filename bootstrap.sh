#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE="personal"
TIER="minimal"
DRY_RUN=0
ASSUME_YES=0

usage() {
  cat <<USAGE
Usage: ./bootstrap.sh [--profile personal|work|minimal|ci] [--tier minimal|cli|full|ci] [--dry-run] [--yes]

Bootstraps a macOS/Linux workstation from this repository.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="${2:?missing profile}"; shift 2 ;;
    --tier) TIER="${2:?missing tier}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --yes|-y) ASSUME_YES=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done


case "$PROFILE" in
  personal|work|minimal|ci) ;;
  *) echo "Unsupported profile: $PROFILE" >&2; exit 2 ;;
esac
case "$TIER" in
  minimal|cli|full|ci) ;;
  *) echo "Unsupported tier: $TIER" >&2; exit 2 ;;
esac

export BOOTSTRAP_PROFILE="$PROFILE"
export BOOTSTRAP_TIER="$TIER"
export BOOTSTRAP_DRY_RUN="$DRY_RUN"
export BOOTSTRAP_ASSUME_YES="$ASSUME_YES"

# shellcheck source=scripts/lib/log.sh
. "$ROOT_DIR/scripts/lib/log.sh"
# shellcheck source=scripts/lib/os.sh
. "$ROOT_DIR/scripts/lib/os.sh"

info "profile=$PROFILE tier=$TIER dry_run=$DRY_RUN os=$(detect_os) arch=$(detect_arch)"

run_step() {
  local name="$1"; shift
  info "step: $name"
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '[dry-run-step] '
    printf '%q ' "$@"
    printf '\n'
  fi
  "$@"
}

run_step "doctor" "$ROOT_DIR/scripts/doctor.sh"
run_step "install system packages" "$ROOT_DIR/scripts/install-system-packages.sh" "--tier" "$TIER"
run_step "install homebrew/linuxbrew" "$ROOT_DIR/scripts/install-homebrew.sh"
run_step "install package manifests" "$ROOT_DIR/scripts/install-packages.sh" "--tier" "$TIER"

if [[ "$TIER" == "cli" || "$TIER" == "full" || "$TIER" == "ci" ]]; then
  run_step "install language tools" "$ROOT_DIR/scripts/install-language-tools.sh" "--tier" "$TIER"
fi

if [[ "$TIER" == "full" ]]; then
  run_step "install VS Code extensions" "$ROOT_DIR/scripts/install-vscode-extensions.sh"
fi

if command -v chezmoi >/dev/null 2>&1; then
  if [[ "$DRY_RUN" == "1" ]]; then
    info "chezmoi dry-run"
    chezmoi diff --source "$ROOT_DIR"
  else
    chezmoi_args=(apply --source "$ROOT_DIR" --override-data "{\"profile\":\"$PROFILE\"}")
    if [[ "$ASSUME_YES" == "1" ]]; then
      chezmoi_args+=(--force)
    fi
    chezmoi "${chezmoi_args[@]}"
  fi
else
  warn "chezmoi is not installed yet; rerun after base tools install"
fi

if is_macos && [[ "$TIER" == "full" ]]; then
  run_step "macOS defaults" "$ROOT_DIR/scripts/setup-macos-defaults.sh"
elif is_linux; then
  run_step "Linux defaults" "$ROOT_DIR/scripts/setup-linux-defaults.sh"
fi

run_step "verify" "$ROOT_DIR/scripts/verify-new-machine.sh" "--tier" "$TIER"
success "bootstrap flow complete"
