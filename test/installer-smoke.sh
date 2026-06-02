#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

./install.sh --help > "$tmp_dir/help.txt"
grep -Fq 'Usage: ./install.sh' "$tmp_dir/help.txt"
grep -Fq 'choose everything from the terminal interface' "$tmp_dir/help.txt"
for flag in --tier --profile --audit --apply --dry-run --plan-only --yes; do
  if grep -q -- "$flag" "$tmp_dir/help.txt"; then
    echo "install help should not expose user-facing install flag: $flag" >&2
    exit 1
  fi
done

for rejected in '--tier cli' '--profile personal' '--audit standard' '--apply' '--dry-run' '--plan-only' '--yes'; do
  read -r -a args <<< "$rejected"
  if ./install.sh "${args[@]}" > "$tmp_dir/flag.txt" 2>&1; then
    echo "expected install flag to be rejected: $rejected" >&2
    exit 1
  fi
  grep -Fq 'selected through the interface' "$tmp_dir/flag.txt"
done

WB_INSTALL_ACTION=plan-only \
WB_INSTALL_PROFILE=personal \
WB_INSTALL_TIER=cli \
WB_INSTALL_AUDIT=standard \
  ./install.sh > "$tmp_dir/plan.txt"
grep -Fq 'action:   plan-only' "$tmp_dir/plan.txt"
grep -Fq './bootstrap.sh --profile personal --tier cli' "$tmp_dir/plan.txt"
grep -Fq 'just private-risk-audit' "$tmp_dir/plan.txt"

if WB_INSTALL_ACTION=apply \
   WB_INSTALL_PROFILE=minimal \
   WB_INSTALL_TIER=minimal \
   WB_INSTALL_AUDIT=none \
   ./install.sh < /dev/null > "$tmp_dir/apply-no-yes.txt" 2>&1; then
  echo 'expected non-interactive apply without explicit automation approval to fail' >&2
  exit 1
fi
grep -Fq 'real apply requires interactive APPLY confirmation' "$tmp_dir/apply-no-yes.txt"

WB_INSTALL_ACTION=dry-run \
WB_INSTALL_PROFILE=minimal \
WB_INSTALL_TIER=ci \
WB_INSTALL_AUDIT=none \
  ./install.sh > "$tmp_dir/dry-run.txt"
grep -Fq 'action:   dry-run' "$tmp_dir/dry-run.txt"
grep -Fq 'installer complete' "$tmp_dir/dry-run.txt"

echo '[OK] installer smoke checks passed'
