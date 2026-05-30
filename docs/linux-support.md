# Linux Support

Current Linux scope is **Ubuntu only**.

## Supported now

- Ubuntu 24.04 LTS baseline via `apt-get`
- Shared dotfile layer through chezmoi
- Shared CLI package layer through Homebrew/Linuxbrew after native prerequisites
- Linux defaults limited to safe directory/shell checks

## Deferred

Fedora, Arch, NixOS, and other Linux distributions are intentionally out of scope for the first migration pass. Do not add `dnf`, `pacman`, or distro-specific package manifests until Ubuntu bootstrap has been verified on a fresh machine or VM.
