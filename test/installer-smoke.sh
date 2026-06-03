#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

./install.sh --help > "$tmp_dir/help.txt"
grep -Fq 'Usage: ./install.sh' "$tmp_dir/help.txt"
grep -Fq 'choose everything from the terminal interface' "$tmp_dir/help.txt"
grep -Fq 'Every run prints a run id, planned flow, and [FLOW] progress markers.' "$tmp_dir/help.txt"
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

if command -v just >/dev/null 2>&1; then
  just --dry-run > "$tmp_dir/just-dry-run.txt" 2>&1
  grep -Fq './install.sh' "$tmp_dir/just-dry-run.txt"
  WB_INSTALL_ACTION=plan-only \
  WB_INSTALL_PROFILE=personal \
  WB_INSTALL_TIER=cli \
  WB_INSTALL_AUDIT=none \
  WB_INSTALL_RUN_ID=just-smoke \
    just > "$tmp_dir/just-plan.txt"
  grep -Fq 'run id:   just-smoke' "$tmp_dir/just-plan.txt"
  grep -Fq 'action:   plan-only' "$tmp_dir/just-plan.txt"
  grep -Fq 'plan rendered; no changes made (run id: just-smoke)' "$tmp_dir/just-plan.txt"
fi

WB_INSTALL_ACTION=plan-only \
WB_INSTALL_PROFILE=personal \
WB_INSTALL_TIER=cli \
WB_INSTALL_AUDIT=standard \
WB_INSTALL_RUN_ID=smoke-plan \
  ./install.sh > "$tmp_dir/plan.txt"
grep -Fq 'action:   plan-only' "$tmp_dir/plan.txt"
grep -Fq 'Planned flow' "$tmp_dir/plan.txt"
grep -Fq 'run id:   smoke-plan' "$tmp_dir/plan.txt"
grep -Fq '1. selection       complete; profile=personal tier=cli audit=standard action=plan-only' "$tmp_dir/plan.txt"
grep -Fq '2. preflight       secret scan + private risk audit' "$tmp_dir/plan.txt"
grep -Fq '3. bootstrap       not executed; plan only' "$tmp_dir/plan.txt"
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
WB_INSTALL_RUN_ID=smoke-dry-run \
  ./install.sh > "$tmp_dir/dry-run.txt"
grep -Fq 'action:   dry-run' "$tmp_dir/dry-run.txt"
grep -Fq 'installer complete' "$tmp_dir/dry-run.txt"
grep -Fq '[FLOW 1/3] preflight audits skipped' "$tmp_dir/dry-run.txt"
grep -Fq '[FLOW 2/3] bootstrap engine: profile=minimal tier=ci action=dry-run' "$tmp_dir/dry-run.txt"
grep -Fq '[FLOW 3/3] installer complete: run id smoke-dry-run' "$tmp_dir/dry-run.txt"

echo '[OK] installer smoke checks passed'
