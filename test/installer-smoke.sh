#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

./install.sh --help > "$tmp_dir/help.txt"
grep -q 'Usage: ./install.sh' "$tmp_dir/help.txt"
grep -q -- '--audit none|standard|full' "$tmp_dir/help.txt"
grep -q -- '--menu' "$tmp_dir/help.txt"

./install.sh --plan-only --profile personal --tier cli --audit standard > "$tmp_dir/plan.txt"
grep -q 'action:   dry-run' "$tmp_dir/plan.txt"
grep -q './bootstrap.sh --profile personal --tier cli --dry-run' "$tmp_dir/plan.txt"
grep -q 'just private-risk-audit' "$tmp_dir/plan.txt"

if ./install.sh --apply --profile minimal --tier minimal --audit none < /dev/null > "$tmp_dir/apply-no-yes.txt" 2>&1; then
  echo 'expected non-interactive apply without --yes to fail' >&2
  exit 1
fi
grep -q 'real apply requires --yes' "$tmp_dir/apply-no-yes.txt"

./install.sh --dry-run --profile minimal --tier ci --audit none --yes > "$tmp_dir/dry-run.txt"
grep -q 'action:   dry-run' "$tmp_dir/dry-run.txt"
grep -q 'installer complete' "$tmp_dir/dry-run.txt"

echo '[OK] installer smoke checks passed'
