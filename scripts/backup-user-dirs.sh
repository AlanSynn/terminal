#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/log.sh
. "$ROOT_DIR/scripts/lib/log.sh"
# shellcheck source=scripts/lib/os.sh
. "$ROOT_DIR/scripts/lib/os.sh"

MANIFEST="$ROOT_DIR/backup/user-dirs.json"
DRIVE=""
APPLY=0
ALLOW_LOCAL_TEST_DESTINATION=0
INIT_MARKER=0

usage() {
  cat <<USAGE
Usage: scripts/backup-user-dirs.sh --drive PATH [--manifest FILE] [--dry-run|--apply] [--init-marker] [--allow-local-test-destination]

Dry-runs rsync mirrors for important user directories into sibling directories at an external drive root.
Apply mode requires an explicit backup-drive marker file and never uses rsync --delete.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --drive) DRIVE="${2:?missing drive path}"; shift 2 ;;
    --manifest) MANIFEST="${2:?missing manifest path}"; shift 2 ;;
    --dry-run) APPLY=0; shift ;;
    --apply) APPLY=1; shift ;;
    --init-marker) INIT_MARKER=1; shift ;;
    --allow-local-test-destination) ALLOW_LOCAL_TEST_DESTINATION=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ -n "$DRIVE" ]] || die "--drive is required"
[[ -f "$MANIFEST" ]] || die "missing backup manifest: $MANIFEST"
command -v python3 >/dev/null 2>&1 || die "python3 is required to read $MANIFEST"
command -v rsync >/dev/null 2>&1 || die "rsync is required for user directory backup"

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
HOME_REAL="$(real_path "$HOME")"
ROOT_REAL="$(real_path "$ROOT_DIR")"
[[ -d "$DRIVE_REAL" ]] || die "backup drive does not exist: $DRIVE_REAL"
[[ "$DRIVE_REAL" != "/" ]] || die "refusing to use / as backup drive"
[[ "$DRIVE_REAL" != "$HOME_REAL" ]] || die "refusing to use HOME as backup drive"
if is_path_within "$HOME_REAL" "$DRIVE_REAL"; then
  die "refusing to use a path inside HOME as backup drive: $DRIVE_REAL"
fi
if is_path_within "$ROOT_REAL" "$DRIVE_REAL"; then
  die "refusing to use repo path as backup drive: $DRIVE_REAL"
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
META_DIR="$(manifest_value metaDir)"
MARKER_PATH="$DRIVE_REAL/$MARKER_NAME"

if [[ ! -f "$MARKER_PATH" ]]; then
  if [[ "$INIT_MARKER" == "1" ]]; then
    if [[ "$APPLY" == "1" ]]; then
      cat > "$MARKER_PATH" <<JSON
{
  "purpose": "workstation-bootstrap-user-data-backup",
  "createdBy": "workstation-bootstrap",
  "version": 1
}
JSON
      success "created backup drive marker: $MARKER_PATH"
    else
      info "[dry-run] would create backup drive marker: $MARKER_PATH"
    fi
  else
    die "missing backup drive marker: $MARKER_PATH (run with --init-marker after verifying the drive root)"
  fi
fi

if [[ "$APPLY" == "1" ]]; then
  mkdir -p "$DRIVE_REAL/$META_DIR/manifests" "$DRIVE_REAL/$META_DIR/logs" "$DRIVE_REAL/$META_DIR/inventories"
  cp "$MANIFEST" "$DRIVE_REAL/$META_DIR/manifests/user-dirs.json"
  if [[ -d "$ROOT_DIR/inventories/current-machine" ]]; then
    rsync -a --delete "$ROOT_DIR/inventories/current-machine/" "$DRIVE_REAL/$META_DIR/inventories/current-machine/"
  fi
else
  info "dry-run mode: no backup data or metadata will be written"
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
  source_spec="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["source"])' "$item_json")"
  dest_rel="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["dest"])' "$item_json")"
  required="$(python3 -c 'import json,sys; print(str(json.loads(sys.argv[1]).get("required", False)).lower())' "$item_json")"
  exclude_files=()
  while IFS= read -r exclude_file_item; do
    exclude_files+=("$exclude_file_item")
  done < <(python3 -c 'import json,sys; print("\n".join(json.loads(sys.argv[1]).get("excludeFiles", [])))' "$item_json")

  source_path="$(real_path "$source_spec")"
  if [[ ! -d "$source_path" ]]; then
    if [[ "$required" == "true" ]]; then
      die "required backup source missing for $id: $source_path"
    fi
    warn "backup source missing; skipping $id: $source_path"
    continue
  fi

  dest_rel="${dest_rel#/}"
  dest_path="$DRIVE_REAL/${dest_rel%/}/"
  dest_real_parent="$(real_path "$(dirname "$dest_path")")"
  if ! is_path_within "$DRIVE_REAL" "$dest_real_parent"; then
    die "destination for $id escapes backup drive: $dest_path"
  fi

  rsync_cmd=(rsync -a --human-readable --itemize-changes)
  [[ "$APPLY" == "0" ]] && rsync_cmd+=(--dry-run)
  for exclude_file in "${exclude_files[@]}"; do
    [[ -n "$exclude_file" ]] || continue
    exclude_path="$ROOT_DIR/backup/excludes/$exclude_file"
    [[ -f "$exclude_path" ]] || die "missing exclude file for $id: $exclude_path"
    rsync_cmd+=(--exclude-from "$exclude_path")
  done
  rsync_cmd+=("$source_path/" "$dest_path")

  info "backup set=$id source=$source_path dest=$dest_path"
  printf '[rsync] '
  quote_cmd "${rsync_cmd[@]}"
  if [[ "$APPLY" == "1" ]]; then
    mkdir -p "$dest_path"
  fi
  "${rsync_cmd[@]}"
done

if [[ "$APPLY" == "1" ]]; then
  success "user directory backup apply complete"
else
  success "user directory backup dry-run complete"
fi
