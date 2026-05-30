#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/log.sh
. "$ROOT_DIR/scripts/lib/log.sh"

manifest="$ROOT_DIR/packages/vscode-extensions.txt"
[[ -f "$manifest" ]] || { warn "no vscode extension manifest at $manifest"; exit 0; }
command -v code >/dev/null 2>&1 || { warn "code CLI unavailable; skipping VS Code extensions"; exit 0; }

grep -Ev '^[[:space:]]*(#|$)' "$manifest" | while IFS= read -r extension; do
  run_or_echo code --install-extension "$extension"
done
