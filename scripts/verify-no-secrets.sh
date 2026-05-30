#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/log.sh
. "$ROOT_DIR/scripts/lib/log.sh"
# shellcheck source=scripts/lib/secrets.sh
. "$ROOT_DIR/scripts/lib/secrets.sh"

failures=0
check_path() {
  local rel="$1"
  if is_runtime_path "$rel"; then
    return 0
  fi
  if is_forbidden_secret_path "$rel"; then
    error "forbidden secret-risk path present: $rel"
    failures=$((failures + 1))
  fi
}

while IFS= read -r -d '' path; do
  rel="${path#"$ROOT_DIR/"}"
  rel="$(normalize_relpath "$rel")"
  is_runtime_path "$rel" && continue
  check_path "$rel"
  if reason="$(secret_reason "$path")"; then
    error "secret-like content ($reason): $rel"
    failures=$((failures + 1))
  fi
done < <(find "$ROOT_DIR" -type f -print0)

# Directory-level checks that do not require tracked files.
for dir in "$ROOT_DIR/key" "$ROOT_DIR/private_dot_gnupg/private-keys-v1.d" "$ROOT_DIR/private_dot_ssh/private-keys"; do
  if [[ -e "$dir" ]]; then
    error "forbidden secret-risk directory present: ${dir#"$ROOT_DIR/"}"
    failures=$((failures + 1))
  fi
done

if [[ "$failures" -gt 0 ]]; then
  die "secret scan failed with $failures issue(s)"
fi
success "secret scan passed"
