set shell := ["bash", "-uc"]
set positional-arguments

# Show commands
default:
    @just --list

# Dry-run minimal bootstrap
bootstrap-dry-run:
    ./bootstrap.sh --dry-run --tier minimal

# Dry-run CLI bootstrap
bootstrap-cli-dry-run:
    ./bootstrap.sh --dry-run --tier cli

# Full bootstrap (non-dry-run)
bootstrap tier="cli":
    ./bootstrap.sh --tier {{tier}}

# Run environment diagnostics
doctor:
    scripts/doctor.sh

# Audit current machine into inventories/current-machine
audit:
    scripts/audit-current-machine.sh


# Build inventory curation report
curate-inventory:
    scripts/curate-inventory.sh

# Audit current machine and build curation report
inventory: audit curate-inventory

# Verify scripts, manifests, backup plan, and secret hygiene
verify: secret-scan shell-syntax manifest-check backup-smoke
    scripts/verify-new-machine.sh --tier ci

# Check shell syntax
shell-syntax:
    bash -n bootstrap.sh scripts/*.sh scripts/lib/*.sh test/*.sh

# Run shellcheck if available
shellcheck:
    if command -v shellcheck >/dev/null 2>&1; then shellcheck bootstrap.sh scripts/*.sh scripts/lib/*.sh test/*.sh; else echo "shellcheck not installed; skipping"; fi

# Scan repository for high-confidence secrets
secret-scan:
    scripts/verify-no-secrets.sh

# Preview sanitized import from old Init
import-init-dry-run:
    scripts/sanitize-import.sh --from /Users/alansynn/Workspace/src/github.com/AlanSynn/Init --dry-run

# Apply sanitized import from old Init
import-init:
    scripts/sanitize-import.sh --from /Users/alansynn/Workspace/src/github.com/AlanSynn/Init --apply

# Chezmoi data rendering
chezmoi-data:
    chezmoi data --source .

# Chezmoi diff, non-fatal while repo is under construction
chezmoi-diff:
    chezmoi diff --source . || true


# Check curated manifests and backup manifest consistency
manifest-check:
    test/manifest-consistency.sh

# Exercise dry-run user-data backup and restore safety checks
backup-smoke:
    test/backup-plan-dry-run.sh

# Dry-run important user directory backup to an external drive root
backup-plan DRIVE:
    scripts/backup-user-dirs.sh --drive '{{DRIVE}}' --dry-run

# Initialize marker and apply important user directory backup to an external drive root
backup-apply DRIVE:
    scripts/backup-user-dirs.sh --drive '{{DRIVE}}' --apply --init-marker

# Dry-run restoring user directory backup into a staging directory
restore-plan DRIVE:
    scripts/restore-user-dirs.sh --drive '{{DRIVE}}' --dry-run

# Build Ubuntu Docker smoke image
ubuntu-smoke:
    docker build -f test/docker/Dockerfile.ubuntu -t workstation-bootstrap-ubuntu-smoke .
