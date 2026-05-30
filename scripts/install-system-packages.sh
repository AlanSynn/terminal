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

read_manifest() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  grep -Ev '^[[:space:]]*(#|$)' "$file"
}

install_with_sudo() {
  if is_dry_run; then
    printf '[dry-run] '
    quote_cmd "$@"
  elif [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

if is_macos; then
  info "macOS native prerequisites"
  if xcode-select -p >/dev/null 2>&1; then
    success "Xcode Command Line Tools present"
  else
    warn "Xcode Command Line Tools missing"
    run_or_echo xcode-select --install
  fi
  exit 0
fi

if ! is_linux; then
  warn "unsupported OS for native packages: $(detect_os)"
  exit 0
fi

linux_distribution="$(linux_id)"
pm="$(package_manager)"
info "Linux distribution: $linux_distribution package_manager=$pm tier=$TIER"

if [[ "$linux_distribution" != "ubuntu" ]]; then
  warn "Linux native prerequisites currently support Ubuntu only; skipping distro-specific install for $linux_distribution"
  exit 0
fi

if [[ "$pm" != "apt" ]]; then
  warn "Ubuntu prerequisites require apt-get; found package_manager=$pm"
  exit 0
fi

mapfile -t packages < <(read_manifest "$ROOT_DIR/packages/apt.ubuntu.txt")
[[ ${#packages[@]} -gt 0 ]] || exit 0
install_with_sudo apt-get update
install_with_sudo apt-get install -y "${packages[@]}"
