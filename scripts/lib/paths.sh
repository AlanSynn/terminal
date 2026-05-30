#!/usr/bin/env bash
# Path helpers.

script_dir() {
  cd "$(dirname "${BASH_SOURCE[1]}")" && pwd
}

repo_root() {
  if git rev-parse --show-toplevel >/dev/null 2>&1; then
    git rev-parse --show-toplevel
  else
    cd "$(dirname "${BASH_SOURCE[1]}")/../.." && pwd
  fi
}

ensure_dir() {
  mkdir -p "$1"
}
