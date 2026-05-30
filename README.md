# workstation-bootstrap

Clean, cross-platform workstation bootstrap for Alan's macOS and Linux development environments.

This repository is an **Init v2**: it reuses the useful scaffold from the old `Init` dotfiles repo, but treats the current machine inventory—not the old repo—as the source of truth. It supports macOS and Linux through chezmoi, Homebrew/Linuxbrew, OS-native package prerequisites, and explicit verification scripts.

## Principles

- No plaintext secrets in git.
- Current machine is evidence, not a binary image.
- macOS and Linux share a core dotfile layer but keep OS-specific packages/defaults separate.
- Apple Silicon and Intel Homebrew paths are detected, not hardcoded.
- Migration Assistant/Time Machine are fallback/data-transfer tools, not the canonical bootstrap.

## Quick start

```bash
./bootstrap.sh --dry-run --tier minimal
./bootstrap.sh --profile personal --tier cli
just verify
```

## Main commands

```bash
just --list
just doctor
just audit
just verify
just secret-scan
just import-init-dry-run
```

## Repo layout

- `masterplan.md` — full implementation and migration plan.
- `bootstrap.sh` — entrypoint for macOS/Linux setup.
- `packages/` — common, macOS, Linux, MAS, and language-tool manifests.
- `scripts/` — install, audit, import, and verification scripts.
- `.chezmoi*`, `dot_*`, `private_dot_*` — chezmoi source files.
- `docs/` — migration/security/platform policy.
- `test/` — smoke tests and container fixtures.

## Safety

Do not run full setup until `just secret-scan` and `just verify` pass. Run dry-run first on every new machine.
