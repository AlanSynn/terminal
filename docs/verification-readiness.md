# Verification Readiness Checklist

This is the current checklist before trusting `workstation-bootstrap` on a new machine.

## Current situation

- Repository has an initial safe bootstrap scaffold and a current-machine inventory snapshot.
- Linux scope is currently Ubuntu only; Fedora/Arch support is deferred.
- Inventory-only entries in `inventories/current-machine/curation-report.md` are review candidates, not install requirements.
- Raw inventory dumps are kept under `inventories/current-machine/raw/` and ignored by git/Docker.
- No full real-machine install has been run yet.

## Immediate tasks

1. Review `inventories/current-machine/curation-report.md` and decide which inventory-only tools should be promoted into package manifests.
2. Validate Ubuntu behavior in Docker on every significant script/package-manifest change.
3. Run a real Ubuntu VM dry-run before using the repo on a real Linux workstation.
4. Run macOS dry-run on the current Mac before applying full-tier defaults.
5. Install `shellcheck` locally or in CI so shell lint stops being skipped.
6. Decide whether VS Code extensions should remain candidates or become a curated install manifest.
7. Decide whether paid/large GUI apps belong in `packages/mas.darwin.txt` or in manual migration notes only.

## Required local verification commands

```bash
just --list
just inventory
scripts/verify-no-secrets.sh
just verify
test/smoke-bootstrap.sh
just ubuntu-smoke
```

## Ubuntu VM verification prep

Before testing on a real Ubuntu VM:

1. Use Ubuntu 24.04 LTS.
2. Start from a disposable VM snapshot.
3. Ensure `git`, `curl`, and `sudo` are available.
4. Clone this repo into the VM.
5. Run `./bootstrap.sh --dry-run --tier minimal` first.
6. Run `./bootstrap.sh --dry-run --tier cli` next.
7. Only after dry-runs pass, run a minimal non-dry-run bootstrap.
8. Re-run `scripts/verify-no-secrets.sh` and `scripts/verify-new-machine.sh --tier ci`.

## macOS verification prep

Before a full macOS apply:

1. Confirm encrypted Time Machine or equivalent backup exists.
2. Run `just inventory` and review the curation report.
3. Run `./bootstrap.sh --dry-run --tier minimal`.
4. Run `chezmoi diff --source .` and inspect any home-directory changes.
5. Do not run full tier until secrets, app logins, and manual migration items are understood.

## Stop conditions

Stop and inspect before applying if any of these occur:

- `scripts/verify-no-secrets.sh` fails.
- `chezmoi diff --source .` shows unexpected credential/app-state files.
- Ubuntu dry-run attempts non-apt distro logic.
- macOS dry-run attempts destructive cleanup or broad app-state copying.
- Any command asks for credentials or production account changes unexpectedly.
