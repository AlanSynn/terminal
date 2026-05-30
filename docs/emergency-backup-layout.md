# Emergency Backup Layout

This repository is the **control plane**, not the data store. On an emergency external drive, clone or pull this repo as one directory and keep large user-data mirrors as sibling directories at the drive root.

## Recommended drive root

```text
/Volumes/<EmergencyDrive>/
├── .workstation-backup-drive.json
├── workstation-bootstrap/        # git clone/pull of this repo
├── Desktop/
├── Documents/
├── Downloads/
├── Workspace/
├── Pictures/
├── Movies/
├── Music/
├── Public/
└── _backup-meta/
    ├── manifests/
    ├── inventories/
    └── logs/
```

Rules:

- Do not place `Desktop/`, `Documents/`, `Downloads/`, `Workspace/`, or other data mirrors inside the git repo.
- Do not `git add` user-data backups.
- Use an encrypted external drive: APFS encrypted on macOS; LUKS or equivalent on Ubuntu.
- Treat this as an emergency/manual restore layer, not a replacement for Time Machine or another full encrypted backup.

## Manifest and excludes

The backup set is defined in `backup/user-dirs.json`.

Enabled by default:

- `~/Desktop`
- `~/Documents`
- `~/Downloads`
- `~/Workspace`
- `~/Pictures`
- `~/Movies`
- `~/Music`
- `~/Public`

Disabled by default until explicitly reviewed:

- `~/Onedrive`
- `~/GaTech Dropbox`
- `~/Zotero`

Rationale: cloud-sync roots and app libraries can duplicate remote data or contain opaque state. Enable them only when the emergency-copy value outweighs size, privacy, and duplication risk.

Exclusions live under `backup/excludes/`. They intentionally avoid credential/session/cache material such as private keys, token JSON files, Keychains, browser profiles, and caches.

## Backup workflow

Dry-run first:

```bash
just backup-plan DRIVE=/Volumes/<EmergencyDrive>
```

Initialize the drive marker and apply only after reviewing dry-run output:

```bash
scripts/backup-user-dirs.sh --drive /Volumes/<EmergencyDrive> --apply --init-marker
```

Safety properties:

- The script refuses `/`, `$HOME`, and repo paths as backup destinations.
- On macOS, the drive must be under `/Volumes` unless `--allow-local-test-destination` is used for tests.
- `rsync --delete` is never used.
- Apply mode writes metadata under `_backup-meta/`, including the backup manifest and current-machine inventory snapshot.

## Restore workflow

Restore is staged by default and uses `rsync --ignore-existing`:

```bash
just restore-plan DRIVE=/Volumes/<EmergencyDrive>
scripts/restore-user-dirs.sh --drive /Volumes/<EmergencyDrive> --apply --destination ~/Restore-Staging/YYYYMMDD
```

Restore order:

1. Install the OS.
2. Clone/pull `workstation-bootstrap`.
3. Run `./bootstrap.sh --dry-run --tier minimal` and then `--tier cli`.
4. Restore user data into staging.
5. Manually promote staged data into live home directories.
6. Re-authenticate accounts and app secrets manually.

For `Workspace`, prefer fresh git clones when possible, then use the backup copy to recover uncommitted work, local-only repositories, and non-git project assets.

## Stop conditions

Stop before apply if any dry-run includes:

- Keychain, browser profile, OAuth/session cache, private SSH/GPG material, or token files.
- A destination that is `/`, `$HOME`, the repo root, or an unmarked drive.
- A restore target that would overwrite live home directories directly.
- A plan that unexpectedly includes app support databases or cloud auth caches.
