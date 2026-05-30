# Migration Checklist

1. Create an encrypted Time Machine or equivalent full-machine backup.
2. Audit current machine inventories with `just inventory` and review `inventories/current-machine/curation-report.md`.
3. Pull/clone this repo on the target machine or emergency external drive.
4. For emergency data copy, use the external-drive layout in `docs/emergency-backup-layout.md` and run `just backup-plan DRIVE=/Volumes/<EmergencyDrive>` before any apply.
5. Run bootstrap dry-run on target: `./bootstrap.sh --dry-run --tier minimal`, then `--tier cli`, then `--tier full` only after inspecting diffs.
6. Apply minimal/cli tier before full tier.
7. Restore user data into a staging directory first; manually promote `Documents`, `Downloads`, `Workspace`, and media directories after review.
8. Re-authenticate cloud and app accounts manually. Do not restore credential caches, browser sessions, Keychains, or opaque app support directories.
9. Keep the old machine and encrypted backup until `just verify`, app launch checks, and user-data spot checks pass.
