#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/log.sh
. "$ROOT_DIR/scripts/lib/log.sh"
# shellcheck source=scripts/lib/os.sh
. "$ROOT_DIR/scripts/lib/os.sh"

PROFILE="${WB_INSTALL_PROFILE:-personal}"
TIER="${WB_INSTALL_TIER:-cli}"
AUDIT_LEVEL="${WB_INSTALL_AUDIT:-standard}"
ACTION="${WB_INSTALL_ACTION:-dry-run}"
ASSUME_YES="${WB_INSTALL_ASSUME_YES:-0}"
RUN_ID="${WB_INSTALL_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)-$$}"

usage() {
  cat <<'USAGE'
Usage: ./install.sh

Run the installer and choose everything from the terminal interface.
There are no normal install flags: profile, tier, audit level, and action are
selected in the menu so a new machine setup starts with one command.

Menu flow:
  1. Profile        personal / work / minimal / ci
  2. Install tier   minimal / cli / full / ci
  3. Audit level    standard / full / none
  4. Action         preview / apply / plan only / quit

Safety:
  - The default action is preview only.
  - Real apply asks you to type APPLY.
  - Non-interactive real apply is refused unless CI explicitly sets approval.

Every run prints a run id, planned flow, and [FLOW] progress markers.
Advanced automation should call bootstrap.sh directly or use the test recipes.
USAGE
}

if [[ $# -gt 0 ]]; then
  case "$1" in
    --help|-h) usage; exit 0 ;;
    *) die "install choices are selected through the interface; run ./install.sh" ;;
  esac
fi

validate_profile() {
  case "$1" in personal|work|minimal|ci) ;; *) die "unsupported profile: $1" ;; esac
}
validate_tier() {
  case "$1" in minimal|cli|full|ci) ;; *) die "unsupported tier: $1" ;; esac
}
validate_audit() {
  case "$1" in none|standard|full) ;; *) die "unsupported audit level: $1" ;; esac
}
validate_action() {
  case "$1" in dry-run|preview|apply|plan-only|plan|quit) ;; *) die "unsupported action: $1" ;; esac
}
validate_bool() {
  case "$1" in 0|1|true|false|yes|no) ;; *) die "unsupported boolean value: $1" ;; esac
}
bool_is_true() {
  case "$1" in 1|true|yes) return 0 ;; *) return 1 ;; esac
}

is_tty() { [[ -t 0 && -t 1 ]]; }

normalize_action() {
  case "$1" in
    preview) printf 'dry-run\n' ;;
    plan) printf 'plan-only\n' ;;
    *) printf '%s\n' "$1" ;;
  esac
}

audit_summary() {
  case "$AUDIT_LEVEL" in
    none) printf 'skip preflight audits\n' ;;
    standard) printf 'secret scan + private risk audit\n' ;;
    full) printf 'secret scan + private risk audit + public audit\n' ;;
  esac
}

bootstrap_summary() {
  case "$ACTION" in
    dry-run) printf 'preview bootstrap for %s/%s\n' "$PROFILE" "$TIER" ;;
    apply) printf 'real bootstrap apply for %s/%s after confirmation\n' "$PROFILE" "$TIER" ;;
    plan-only) printf 'not executed; plan only\n' ;;
  esac
}

trace_step() {
  printf '[FLOW %s] %s\n' "$1" "$2"
}

print_flow() {
  cat <<FLOW
Planned flow
------------
run id:   $RUN_ID
1. selection       complete; profile=$PROFILE tier=$TIER audit=$AUDIT_LEVEL action=$ACTION
2. preflight       $(audit_summary)
3. bootstrap       $(bootstrap_summary)
4. finish          final status and next-step signal
FLOW
}

menu_choice() {
  local title="$1" current="$2" default_value="$3"
  shift 3
  local specs=("$@")
  local answer value label i

  if ! is_tty; then
    printf '%s\n' "${current:-$default_value}"
    return 0
  fi

  while true; do
    printf '\n%s\n' "$title" > /dev/tty
    printf '%s\n' "$(printf '%*s' "${#title}" '' | tr ' ' '-')" > /dev/tty
    i=1
    for spec in "${specs[@]}"; do
      value="${spec%%|*}"
      label="${spec#*|}"
      if [[ "$value" == "${current:-$default_value}" ]]; then
        printf '  %d) %s  [default]\n' "$i" "$label" > /dev/tty
      else
        printf '  %d) %s\n' "$i" "$label" > /dev/tty
      fi
      i=$((i + 1))
    done
    printf 'Choose 1-%d [%s]: ' "${#specs[@]}" "${current:-$default_value}" > /dev/tty
    IFS= read -r answer < /dev/tty || answer=""
    answer="${answer:-${current:-$default_value}}"

    if [[ "$answer" =~ ^[0-9]+$ ]] && (( answer >= 1 && answer <= ${#specs[@]} )); then
      value="${specs[$((answer - 1))]%%|*}"
      printf '%s\n' "$value"
      return 0
    fi
    for spec in "${specs[@]}"; do
      value="${spec%%|*}"
      if [[ "$answer" == "$value" ]]; then
        printf '%s\n' "$value"
        return 0
      fi
    done
    warn "invalid choice: $answer"
  done
}

select_from_interface() {
  if is_tty; then
    cat > /dev/tty <<'BANNER'

workstation-bootstrap installer
-------------------------------
Run one command, choose from the interface, preview first, apply only when ready.
BANNER
  else
    info "non-interactive mode: using WB_INSTALL_* environment/default selections"
  fi

  PROFILE="$(menu_choice 'Profile' "$PROFILE" 'personal' \
    'personal|personal — normal personal workstation' \
    'work|work — reserved work profile' \
    'minimal|minimal — smallest dotfile/profile layer' \
    'ci|ci — validation/container profile')"
  validate_profile "$PROFILE"

  TIER="$(menu_choice 'Install tier' "$TIER" 'cli' \
    'minimal|minimal — native prereqs, brew/linuxbrew, common packages, dotfiles' \
    'cli|cli — minimal + language tools and shared CLI tooling' \
    'full|full — cli + macOS GUI apps, MAS, VS Code extensions, OS defaults' \
    'ci|ci — validation/container-friendly path')"
  validate_tier "$TIER"

  AUDIT_LEVEL="$(menu_choice 'Preflight audit' "$AUDIT_LEVEL" 'standard' \
    'standard|standard — secret scan + private risk report' \
    'full|full — standard + public readiness audit' \
    'none|none — skip installer preflight audits')"
  validate_audit "$AUDIT_LEVEL"

  ACTION="$(menu_choice 'Action' "$ACTION" 'dry-run' \
    'dry-run|preview — show and run safe dry-run bootstrap' \
    'apply|apply — real bootstrap apply; asks for APPLY confirmation' \
    'plan-only|plan only — print selected plan and exit' \
    'quit|quit — exit without running anything')"
  ACTION="$(normalize_action "$ACTION")"
  validate_action "$ACTION"
}

validate_profile "$PROFILE"
validate_tier "$TIER"
validate_audit "$AUDIT_LEVEL"
ACTION="$(normalize_action "$ACTION")"
validate_action "$ACTION"
validate_bool "$ASSUME_YES"

select_from_interface

if [[ "$ACTION" == "quit" ]]; then
  info "aborted before any action"
  exit 0
fi

print_plan() {
  local bootstrap_args=(--profile "$PROFILE" --tier "$TIER")
  [[ "$ACTION" == "dry-run" ]] && bootstrap_args+=(--dry-run)
  if [[ "$ACTION" == "apply" ]] && bool_is_true "$ASSUME_YES"; then
    bootstrap_args+=(--yes)
  fi

  cat <<PLAN

Selected plan
-------------
repo:     $ROOT_DIR
os:       $(detect_os) / $(detect_arch)
profile:  $PROFILE
tier:     $TIER
audit:    $AUDIT_LEVEL
action:   $ACTION

Bootstrap engine command:
  ./bootstrap.sh ${bootstrap_args[*]}
PLAN

  print_flow

  case "$AUDIT_LEVEL" in
    none)
      cat <<'PLAN'
Preflight audits:
  (skipped by menu selection)
PLAN
      ;;
    standard)
      cat <<'PLAN'
Preflight audits:
  scripts/verify-no-secrets.sh
  just private-risk-audit
PLAN
      ;;
    full)
      cat <<'PLAN'
Preflight audits:
  scripts/verify-no-secrets.sh
  just private-risk-audit
  just public-audit
PLAN
      ;;
  esac
}

confirm_apply() {
  [[ "$ACTION" == "apply" ]] || return 0
  if bool_is_true "$ASSUME_YES"; then
    return 0
  fi
  if ! is_tty; then
    die "real apply requires interactive APPLY confirmation"
  fi
  local answer
  printf '\nType APPLY to run a real %s/%s bootstrap: ' "$PROFILE" "$TIER" > /dev/tty
  IFS= read -r answer < /dev/tty || answer=""
  [[ "$answer" == "APPLY" ]] || die "apply cancelled"
}

run_audits() {
  case "$AUDIT_LEVEL" in
    none)
      trace_step "1/3" "preflight audits skipped"
      info "preflight audits skipped"
      ;;
    standard|full)
      trace_step "1/3" "preflight audits: $AUDIT_LEVEL"
      "$ROOT_DIR/scripts/verify-no-secrets.sh"
      if command -v just >/dev/null 2>&1; then
        (cd "$ROOT_DIR" && just private-risk-audit)
        if [[ "$AUDIT_LEVEL" == "full" ]]; then
          (cd "$ROOT_DIR" && just public-audit)
        fi
      else
        warn "just unavailable; skipping just-based private/public audits"
      fi
      ;;
  esac
}

run_bootstrap() {
  local bootstrap_args=(--profile "$PROFILE" --tier "$TIER")
  [[ "$ACTION" == "dry-run" ]] && bootstrap_args+=(--dry-run)
  if [[ "$ACTION" == "apply" ]] && bool_is_true "$ASSUME_YES"; then
    bootstrap_args+=(--yes)
  fi
  trace_step "2/3" "bootstrap engine: profile=$PROFILE tier=$TIER action=$ACTION"
  "$ROOT_DIR/bootstrap.sh" "${bootstrap_args[@]}"
}

print_plan
if [[ "$ACTION" == "plan-only" ]]; then
  success "plan rendered; no changes made (run id: $RUN_ID)"
  exit 0
fi
confirm_apply
run_audits
run_bootstrap
trace_step "3/3" "installer complete: run id $RUN_ID"
success "installer complete"
