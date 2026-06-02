#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/log.sh
. "$ROOT_DIR/scripts/lib/log.sh"
# shellcheck source=scripts/lib/os.sh
. "$ROOT_DIR/scripts/lib/os.sh"

PROFILE="personal"
TIER="cli"
ACTION="dry-run"
AUDIT_LEVEL="standard"
ASSUME_YES=0
PLAN_ONLY=0
PROMPT=auto
MENU=auto
SAW_OPTION=0

usage() {
  cat <<'USAGE'
Usage: ./install.sh [options]

A friendly workstation-bootstrap installer. It wraps bootstrap.sh and defaults to
safe preview mode, then lets you choose how much of the workstation to apply.

Common starts:
  ./install.sh                                # interactive menu when a TTY exists
  ./install.sh --dry-run --tier cli           # preview terminal/CLI setup
  ./install.sh --apply --tier minimal         # real minimal apply; asks to confirm
  ./install.sh --apply --tier full --yes      # non-interactive full apply
  ./install.sh --plan-only --tier full        # show what would run, then exit

Options:
  --profile personal|work|minimal|ci          dotfile/profile data passed to chezmoi
  --tier minimal|cli|full|ci                  install scope; default: cli
  --dry-run                                   preview only; default action
  --apply                                     perform real bootstrap apply
  --audit none|standard|full                  preflight audit level; default: standard
                                               none     = skip installer preflight audits
                                               standard = secret scan + private risk report
                                               full     = standard + public readiness audit
  --skip-audits                               alias for --audit none
  --plan-only                                 print selected plan and commands only
  --yes, -y                                   do not prompt; required for non-TTY apply
  --menu                                      force the interactive menu
  --no-prompt                                 never prompt; fail apply unless --yes
  --help, -h                                  show this help

Tiers:
  minimal  native prerequisites, Homebrew/Linuxbrew, common packages, dotfiles
  cli      minimal + language tools and shared CLI tooling; recommended default
  full     cli + macOS GUI casks, MAS apps, VS Code extensions, OS defaults
  ci       validation/container-friendly path
USAGE
}

validate_profile() {
  case "$1" in personal|work|minimal|ci) ;; *) die "unsupported profile: $1" ;; esac
}
validate_tier() {
  case "$1" in minimal|cli|full|ci) ;; *) die "unsupported tier: $1" ;; esac
}
validate_audit() {
  case "$1" in none|standard|full) ;; *) die "unsupported audit level: $1" ;; esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) SAW_OPTION=1; PROFILE="${2:?missing profile}"; shift 2 ;;
    --tier) SAW_OPTION=1; TIER="${2:?missing tier}"; shift 2 ;;
    --dry-run|--preview) SAW_OPTION=1; ACTION="dry-run"; shift ;;
    --apply) SAW_OPTION=1; ACTION="apply"; shift ;;
    --audit) SAW_OPTION=1; AUDIT_LEVEL="${2:?missing audit level}"; shift 2 ;;
    --skip-audits|--no-audit|--no-audits) SAW_OPTION=1; AUDIT_LEVEL="none"; shift ;;
    --plan-only) SAW_OPTION=1; PLAN_ONLY=1; shift ;;
    --yes|-y) SAW_OPTION=1; ASSUME_YES=1; shift ;;
    --menu) MENU=always; shift ;;
    --no-prompt|--non-interactive) SAW_OPTION=1; PROMPT=never; shift ;;
    --help|-h) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

validate_profile "$PROFILE"
validate_tier "$TIER"
validate_audit "$AUDIT_LEVEL"

is_tty() { [[ -t 0 && -t 1 && "$PROMPT" != "never" ]]; }

choose_from_list() {
  local label="$1" current="$2" values="$3" answer
  printf '%s [%s] (%s): ' "$label" "$current" "$values"
  IFS= read -r answer || answer=""
  printf '%s\n' "${answer:-$current}"
}

maybe_prompt() {
  is_tty || return 0
  if [[ "$MENU" != "always" && "$SAW_OPTION" == "1" ]]; then
    return 0
  fi
  cat <<'BANNER'

workstation-bootstrap
---------------------
A safe, staged installer for this Mac/Ubuntu developer environment.
Default action is preview only; real apply always asks before it runs.
BANNER

  PROFILE="$(choose_from_list 'Profile' "$PROFILE" 'personal work minimal ci')"
  validate_profile "$PROFILE"
  TIER="$(choose_from_list 'Tier' "$TIER" 'minimal cli full ci')"
  validate_tier "$TIER"
  AUDIT_LEVEL="$(choose_from_list 'Preflight audit' "$AUDIT_LEVEL" 'none standard full')"
  validate_audit "$AUDIT_LEVEL"

  local action_answer
  printf 'Action [dry-run] (dry-run apply plan-only quit): '
  IFS= read -r action_answer || action_answer=""
  action_answer="${action_answer:-dry-run}"
  case "$action_answer" in
    dry-run|preview) ACTION="dry-run" ;;
    apply) ACTION="apply" ;;
    plan-only|plan) PLAN_ONLY=1 ;;
    quit|q|exit) info "aborted before any action"; exit 0 ;;
    *) die "unsupported action: $action_answer" ;;
  esac
}

print_plan() {
  local bootstrap_args=(--profile "$PROFILE" --tier "$TIER")
  [[ "$ACTION" == "dry-run" ]] && bootstrap_args+=(--dry-run)
  [[ "$ASSUME_YES" == "1" ]] && bootstrap_args+=(--yes)

  cat <<PLAN

Plan
----
repo:     $ROOT_DIR
os:       $(detect_os) / $(detect_arch)
profile:  $PROFILE
tier:     $TIER
action:   $ACTION
audit:    $AUDIT_LEVEL

Bootstrap command:
  ./bootstrap.sh ${bootstrap_args[*]}
PLAN

  case "$AUDIT_LEVEL" in
    none)
      cat <<'PLAN'
Preflight audits:
  (skipped by request)
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
  if [[ "$ASSUME_YES" == "1" ]]; then
    return 0
  fi
  if ! is_tty; then
    die "real apply requires --yes in non-interactive mode"
  fi
  local answer
  printf '\nType APPLY to run a real %s/%s bootstrap: ' "$PROFILE" "$TIER"
  IFS= read -r answer || answer=""
  [[ "$answer" == "APPLY" ]] || die "apply cancelled"
}

run_audits() {
  case "$AUDIT_LEVEL" in
    none)
      info "preflight audits skipped"
      ;;
    standard|full)
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
  [[ "$ASSUME_YES" == "1" ]] && bootstrap_args+=(--yes)
  "$ROOT_DIR/bootstrap.sh" "${bootstrap_args[@]}"
}

maybe_prompt
print_plan
if [[ "$PLAN_ONLY" == "1" ]]; then
  success "plan rendered; no changes made"
  exit 0
fi
confirm_apply
run_audits
run_bootstrap
success "installer complete"
