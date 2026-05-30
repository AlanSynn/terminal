#!/usr/bin/env bash
# High-confidence secret/path detection shared by import and verification scripts.

normalize_relpath() {
  local path="$1"
  path="${path#./}"
  printf '%s\n' "$path"
}

is_runtime_path() {
  local path
  path="$(normalize_relpath "$1")"
  case "$path" in
    .git|.git/*|.omx|.omx/*|inventories/current-machine/raw|inventories/current-machine/raw/*)
      return 0
      ;;
  esac
  return 1
}

is_forbidden_secret_path() {
  local path base
  path="$(normalize_relpath "$1")"
  base="$(basename "$path")"
  case "$path" in
    key|key/*|private_Library|private_Library/*|private_dot_config/github-copilot/apps.json|private_dot_gnupg/private-keys-v1.d|private_dot_gnupg/private-keys-v1.d/*|private_dot_ssh/private-keys|private_dot_ssh/private-keys/*)
      return 0
      ;;
  esac
  case "$base" in
    id_rsa|id_rsa.pub|id_ed25519|id_ed25519.pub|id_ecdsa|id_ecdsa.pub|known_hosts|.env|.env.*|*.pem|*.p12|*.pfx|*.key)
      return 0
      ;;
  esac
  case "$path" in
    */credentials.json|*/credentials|*/token.json|*/tokens.json|*/keys.json|*/client_secret.json|*/service-account.json)
      return 0
      ;;
  esac
  return 1
}

is_probably_text() {
  local file="$1"
  [[ -f "$file" ]] || return 1
  [[ -s "$file" ]] || return 0
  LC_ALL=C grep -Iq . "$file"
}

secret_reason() {
  local file="$1"
  is_probably_text "$file" || return 1

  if LC_ALL=C grep -Eq 'BEGIN [A-Z0-9 ]*PRIVATE KEY' "$file"; then
    printf 'private-key-header'
    return 0
  fi
  if LC_ALL=C grep -Eq '(gh[pousr]|github_pat)_[A-Za-z0-9_]{20,}' "$file"; then
    printf 'github-token'
    return 0
  fi
  if LC_ALL=C grep -Eq 'AKIA[0-9A-Z]{16}' "$file"; then
    printf 'aws-access-key-id'
    return 0
  fi
  if LC_ALL=C grep -Eq 'sk-(proj-|ant-)?[A-Za-z0-9_-]{20,}' "$file"; then
    printf 'api-key-token'
    return 0
  fi
  if LC_ALL=C grep -Eq 'AIza[0-9A-Za-z_-]{35}' "$file"; then
    printf 'google-api-key'
    return 0
  fi
  if LC_ALL=C grep -Eq 'xox[baprs]-[0-9A-Za-z-]{20,}' "$file"; then
    printf 'slack-token'
    return 0
  fi
  if LC_ALL=C grep -Eq '"oauth[_-]?token"[[:space:]]*:[[:space:]]*"[^"]{12,}"' "$file"; then
    printf 'oauth-token-json'
    return 0
  fi
  if LC_ALL=C grep -Eq '"(access_token|refresh_token|client_secret|private_key)"[[:space:]]*:[[:space:]]*"[^"]{16,}"' "$file"; then
    printf 'credential-json-field'
    return 0
  fi
  return 1
}
