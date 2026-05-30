#!/usr/bin/env bash
# Shared logging helpers for workstation-bootstrap.

if [[ -t 1 ]]; then
  _wb_blue=$'\033[34m'
  _wb_green=$'\033[32m'
  _wb_yellow=$'\033[33m'
  _wb_red=$'\033[31m'
  _wb_reset=$'\033[0m'
else
  _wb_blue=""
  _wb_green=""
  _wb_yellow=""
  _wb_red=""
  _wb_reset=""
fi

info() { printf '%s[INFO]%s %s\n' "$_wb_blue" "$_wb_reset" "$*"; }
success() { printf '%s[OK]%s %s\n' "$_wb_green" "$_wb_reset" "$*"; }
warn() { printf '%s[WARN]%s %s\n' "$_wb_yellow" "$_wb_reset" "$*" >&2; }
error() { printf '%s[ERROR]%s %s\n' "$_wb_red" "$_wb_reset" "$*" >&2; }
die() { error "$*"; exit 1; }

is_dry_run() { [[ "${BOOTSTRAP_DRY_RUN:-0}" == "1" ]]; }

quote_cmd() {
  local part
  for part in "$@"; do
    printf '%q ' "$part"
  done
  printf '\n'
}

run_or_echo() {
  if is_dry_run; then
    printf '[dry-run] '
    quote_cmd "$@"
  else
    "$@"
  fi
}
