#!/usr/bin/env bash
# OS and package-manager detection helpers.

detect_os() {
  case "$(uname -s)" in
    Darwin) printf 'darwin\n' ;;
    Linux) printf 'linux\n' ;;
    *) uname -s | tr '[:upper:]' '[:lower:]' ;;
  esac
}

detect_arch() {
  case "$(uname -m)" in
    arm64|aarch64) printf 'arm64\n' ;;
    x86_64|amd64) printf 'amd64\n' ;;
    *) uname -m ;;
  esac
}

is_macos() { [[ "$(detect_os)" == "darwin" ]]; }
is_linux() { [[ "$(detect_os)" == "linux" ]]; }

linux_id() {
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    printf '%s\n' "${ID:-linux}"
  else
    printf 'linux\n'
  fi
}

linux_id_like() {
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    printf '%s %s\n' "${ID:-linux}" "${ID_LIKE:-}"
  else
    printf 'linux\n'
  fi
}

package_manager() {
  if command -v apt-get >/dev/null 2>&1; then printf 'apt\n'; return; fi
  if command -v dnf >/dev/null 2>&1; then printf 'dnf\n'; return; fi
  if command -v pacman >/dev/null 2>&1; then printf 'pacman\n'; return; fi
  if command -v zypper >/dev/null 2>&1; then printf 'zypper\n'; return; fi
  printf 'unknown\n'
}

brew_candidates() {
  printf '%s\n' \
    /opt/homebrew/bin/brew \
    /usr/local/bin/brew \
    /home/linuxbrew/.linuxbrew/bin/brew
}

find_brew() {
  if command -v brew >/dev/null 2>&1; then
    command -v brew
    return 0
  fi
  local candidate
  while IFS= read -r candidate; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done < <(brew_candidates)
  return 1
}

load_homebrew_env() {
  local brew_bin
  if brew_bin="$(find_brew)"; then
    eval "$("$brew_bin" shellenv)"
    return 0
  fi
  return 1
}
