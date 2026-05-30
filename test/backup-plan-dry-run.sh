#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/log.sh
. "$ROOT_DIR/scripts/lib/log.sh"

tmp="$(mktemp -d)"
cleanup() { rm -rf "$tmp"; }
trap cleanup EXIT

fake_home="$tmp/home"
fake_drive="$tmp/drive"
restore_dest="$tmp/restore-staging"
mkdir -p "$fake_home/Documents" "$fake_home/Downloads" "$fake_home/Workspace/project" "$fake_drive"
printf 'doc\n' > "$fake_home/Documents/example.txt"
printf 'download\n' > "$fake_home/Downloads/file.txt"
printf 'work\n' > "$fake_home/Workspace/project/README.md"
cat > "$fake_drive/.workstation-backup-drive.json" <<'JSON'
{"purpose":"workstation-bootstrap-user-data-backup","createdBy":"test","version":1}
JSON

backup_log="$tmp/backup.log"
HOME="$fake_home" "$ROOT_DIR/scripts/backup-user-dirs.sh" \
  --drive "$fake_drive" \
  --dry-run \
  --allow-local-test-destination > "$backup_log"

grep -q -- '--dry-run' "$backup_log" || die "backup dry-run did not invoke rsync --dry-run"
grep -q 'Documents' "$backup_log" || die "backup dry-run did not include Documents"
grep -q 'Workspace' "$backup_log" || die "backup dry-run did not include Workspace"
[[ ! -e "$fake_drive/Documents/example.txt" ]] || die "backup dry-run wrote files"

mkdir -p "$fake_drive/Documents" "$fake_drive/Workspace/project"
printf 'doc\n' > "$fake_drive/Documents/example.txt"
printf 'work\n' > "$fake_drive/Workspace/project/README.md"
restore_log="$tmp/restore.log"
HOME="$fake_home" "$ROOT_DIR/scripts/restore-user-dirs.sh" \
  --drive "$fake_drive" \
  --destination "$restore_dest" \
  --dry-run \
  --allow-local-test-destination > "$restore_log"

grep -q -- '--dry-run' "$restore_log" || die "restore dry-run did not invoke rsync --dry-run"
grep -q -- '--ignore-existing' "$restore_log" || die "restore dry-run did not use --ignore-existing"
[[ ! -e "$restore_dest/Documents/example.txt" ]] || die "restore dry-run wrote files"

if "$ROOT_DIR/scripts/backup-user-dirs.sh" --drive "$fake_home" --dry-run --allow-local-test-destination >/dev/null 2>&1; then
  die "backup script accepted HOME as drive"
fi

mkdir -p "$fake_home/BackupDrive"
if "$ROOT_DIR/scripts/backup-user-dirs.sh" --drive "$fake_home/BackupDrive" --dry-run --allow-local-test-destination >/dev/null 2>&1; then
  die "backup script accepted a path inside HOME as drive"
fi

success "backup/restore dry-run safety checks passed"
