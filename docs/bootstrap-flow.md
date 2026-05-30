# Bootstrap Flow

The entrypoint is `./bootstrap.sh`. It is intentionally staged so a fresh machine can start with a safe dry-run and then graduate to real install tiers.

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
6. `chezmoi diff` or `chezmoi apply` renders dotfiles.
7. OS defaults run only for explicit target/tier branches.
8. `scripts/verify-new-machine.sh` runs final safety and syntax checks.

Dry-run mode sets `BOOTSTRAP_DRY_RUN=1`; install scripts print the commands they would run rather than mutating the host.


## Inventory curation

Use `just inventory` on the source machine to write names-only inventory files and `inventories/current-machine/curation-report.md`. Treat inventory-only entries as review candidates; do not automatically promote every discovered GUI app or global package into the canonical manifests. Raw command dumps are written under `inventories/current-machine/raw/`, which is ignored and skipped by the secret scanner.
