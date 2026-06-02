# Bootstrap Flow

The friendly entrypoint is `./install.sh`; it presents an interface-first terminal menu and wraps `./bootstrap.sh`, which remains the deterministic engine. The flow is intentionally staged so a fresh machine can start with one command, choose a safe dry-run/plan/apply action in the interface, and then graduate to real install tiers.

## Tiers

- `minimal`: native prerequisites, Homebrew/Linuxbrew availability, common CLI manifest, chezmoi diff/apply, verification.
- `cli`: `minimal` plus shared Linuxbrew package layer and language tool manifests.
- `full`: `cli` plus macOS GUI casks, MAS apps, and explicit OS defaults.
- `ci`: dry-run/container-friendly validation path.

## Order

1. `scripts/doctor.sh` reports OS, architecture, and tool availability.
2. `scripts/install-system-packages.sh` handles macOS CLT or Linux native prerequisites.
3. `scripts/install-homebrew.sh` detects or installs Homebrew/Linuxbrew.
4. `scripts/install-packages.sh` applies tier-aware Brewfiles and MAS apps.
5. `scripts/install-language-tools.sh` applies npm/bun/uv/cargo manifests for CLI/full/CI tiers.
6. For `full` tier, `scripts/install-vscode-extensions.sh` applies the canonical VS Code extension manifest when the `code` CLI is available.
7. `chezmoi diff` or `chezmoi apply` renders dotfiles.
8. OS defaults run only for explicit target/tier branches.
9. `scripts/verify-new-machine.sh` runs final safety and syntax checks.

When the menu action is preview/dry-run, the wrapper calls the engine in dry-run mode. Dry-run mode sets `BOOTSTRAP_DRY_RUN=1`; install scripts print the commands they would run rather than mutating the host.


## Inventory curation

Use `just inventory` on the source machine to write names-only inventory files and `inventories/current-machine/curation-report.md`. Treat inventory-only entries as review candidates; do not automatically promote every discovered GUI app or global package into the canonical manifests. Raw command dumps are written under `inventories/current-machine/raw/`, which is ignored and skipped by the secret scanner.

## User-data backup

Large user directories are not managed by chezmoi or git. Use `backup/user-dirs.json`, `scripts/backup-user-dirs.sh`, and `scripts/restore-user-dirs.sh` to dry-run rsync mirrors into sibling directories at an external drive root. See `docs/emergency-backup-layout.md`.
