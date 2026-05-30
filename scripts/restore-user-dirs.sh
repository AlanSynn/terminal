#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/log.sh
. "$ROOT_DIR/scripts/lib/log.sh"
# shellcheck source=scripts/lib/os.sh
. "$ROOT_DIR/scripts/lib/os.sh"

MANIFEST="$ROOT_DIR/backup/user-dirs.json"
DRIVE=""
DESTINATION="$HOME/Restore-Staging/$(date +%Y%m%d-%H%M%S)"
APPLY=0
ALLOW_LOCAL_TEST_DESTINATION=0

usage() {
  cat <<USAGE
Usage: scripts/restore-user-dirs.sh --drive PATH [--destination PATH] [--manifest FILE] [--dry-run|--apply] [--allow-local-test-destination]

Restores external-drive sibling backup directories into a staging directory. It never restores directly into live home directories by default and uses rsync --ignore-existing.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --drive) DRIVE="${2:?missing drive path}"; shift 2 ;;
    --destination) DESTINATION="${2:?missing destination path}"; shift 2 ;;
    --manifest) MANIFEST="${2:?missing manifest path}"; shift 2 ;;
    --dry-run) APPLY=0; shift ;;
    --apply) APPLY=1; shift ;;
    --allow-local-test-destination) ALLOW_LOCAL_TEST_DESTINATION=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ -n "$DRIVE" ]] || die "--drive is required"
[[ -f "$MANIFEST" ]] || die "missing backup manifest: $MANIFEST"
command -v python3 >/dev/null 2>&1 || die "python3 is required to read $MANIFEST"
command -v rsync >/dev/null 2>&1 || die "rsync is required for user directory restore"

real_path() {
  python3 - "$1" <<'PY'
import os, sys
print(os.path.realpath(os.path.expanduser(sys.argv[1])))
PY
}

is_path_within() {
  local parent="$1" child="$2"
  [[ "$child" == "$parent" || "$child" == "$parent"/* ]]
}

manifest_value() {
  python3 - "$MANIFEST" "$1" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as f:
    data = json.load(f)
print(data[sys.argv[2]])
PY
}

DRIVE_REAL="$(real_path "$DRIVE")"
DEST_REAL="$(real_path "$DESTINATION")"
HOME_REAL="$(real_path "$HOME")"
ROOT_REAL="$(real_path "$ROOT_DIR")"
[[ -d "$DRIVE_REAL" ]] || die "backup drive does not exist: $DRIVE_REAL"
[[ "$DRIVE_REAL" != "/" ]] || die "refusing to use / as backup drive"
[[ "$DEST_REAL" != "/" ]] || die "refusing to restore into /"
[[ "$DEST_REAL" != "$HOME_REAL" ]] || die "refusing to restore directly into HOME"
if is_path_within "$ROOT_REAL" "$DEST_REAL"; then
  die "refusing to restore into repo path: $DEST_REAL"
fi

if [[ "$ALLOW_LOCAL_TEST_DESTINATION" != "1" ]]; then
  if is_macos && [[ "$DRIVE_REAL" != /Volumes/* ]]; then
    die "backup drive should be under /Volumes on macOS; pass --allow-local-test-destination only for tests"
  fi
  if is_linux && [[ "$DRIVE_REAL" != /mnt/* && "$DRIVE_REAL" != /media/* && "$DRIVE_REAL" != /run/media/* ]]; then
    die "backup drive should be under /mnt, /media, or /run/media on Linux; pass --allow-local-test-destination only for tests"
  fi
fi

MARKER_NAME="$(manifest_value driveMarker)"
MARKER_PATH="$DRIVE_REAL/$MARKER_NAME"
[[ -f "$MARKER_PATH" ]] || die "missing backup drive marker: $MARKER_PATH"

if [[ "$APPLY" == "1" ]]; then
  mkdir -p "$DEST_REAL"
else
  info "dry-run mode: no restored files will be written"
fi

platform="$(detect_os)"
python3 - "$MANIFEST" "$platform" <<'PY' | while IFS= read -r item_json; do
import json, sys
manifest, platform = sys.argv[1], sys.argv[2]
with open(manifest, encoding='utf-8') as f:
    data = json.load(f)
for item in data.get('sets', []):
    if not item.get('enabled', True):
        continue
    if platform not in item.get('platforms', []):
        continue
    print(json.dumps(item, separators=(',', ':')))
PY
  id="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["id"])' "$item_json")"
  dest_rel="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["dest"])' "$item_json")"
  dest_rel="${dest_rel#/}"
  source_path="$DRIVE_REAL/${dest_rel%/}/"
  target_path="$DEST_REAL/${dest_rel%/}/"
  if [[ ! -d "$source_path" ]]; then
    warn "restore source missing; skipping $id: $source_path"
    continue
  fi
  target_parent="$(real_path "$(dirname "$target_path")")"
  if ! is_path_within "$DEST_REAL" "$target_parent"; then
    die "restore destination for $id escapes staging root: $target_path"
  fi

  rsync_cmd=(rsync -a --human-readable --itemize-changes --ignore-existing)
  [[ "$APPLY" == "0" ]] && rsync_cmd+=(--dry-run)
  rsync_cmd+=("$source_path" "$target_path")

  info "restore set=$id source=$source_path staging=$target_path"
  printf '[rsync] '
  quote_cmd "${rsync_cmd[@]}"
  if [[ "$APPLY" == "1" ]]; then
    mkdir -p "$target_path"
  fi
  "${rsync_cmd[@]}"
done

if [[ "$APPLY" == "1" ]]; then
  success "user directory restore apply complete"
else
  success "user directory restore dry-run complete"
fi
