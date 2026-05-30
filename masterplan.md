# Master Plan: Init v2 Cross-Platform Bootstrap Repository

Status: **planning / ralplan phase**
Scope: create a new repo in this workspace by reusing the existing `Init` repository as a scaffold, not as a trusted source of truth.
Primary target: reproducible personal developer workstation setup for **macOS + Linux**.
Hard rule: **do not copy secrets, live credentials, caches, or opaque app state into the new repo.**

---

## 0. Executive Decision

The best path is **Init v2**:

1. Reuse the useful structure from `/Users/alansynn/Workspace/src/github.com/AlanSynn/Init`:
   - chezmoi layout
   - bootstrap scripts
   - Justfile command surface
   - macOS defaults script
   - Homebrew/Brewfile workflow
   - external dependency pattern
   - README conventions
2. Do **not** trust Init as current truth:
   - current machine inventory is newer than Init manifests
   - Init contains legacy folders and machine-specific assumptions
   - Init contains secret-risk files and a private-key submodule
   - Init has Intel/Homebrew `/usr/local` hardcoding
3. Build a new clean repo here, provisionally named `mac-bootstrap` or `workstation-bootstrap`, with macOS and Linux first-class support.

Recommended final name: **`workstation-bootstrap`**.
Reason: the repo should support Mac and Linux; `mac-bootstrap` is too narrow.

---

## 1. Success Criteria

The project is successful when a fresh machine can run:

```bash
./bootstrap.sh --profile personal --tier full
```

and then pass:

```bash
just doctor
just verify
just audit
```

with evidence that:

- dotfiles apply through chezmoi without unexpected diffs
- packages install through OS-aware package manifests
- macOS casks/MAS apps are separated from Linux flows
- Linux package prerequisites are handled for Ubuntu first; Fedora/Arch are deferred
- secrets are absent from git and either re-authenticated or provided through an encrypted/password-manager-backed path
- Apple Silicon and Intel Homebrew prefixes both work
- setup can run in dry-run/minimal/full modes
- CI or local containers smoke-test Linux bootstrap logic

---

## 2. Non-Goals

This repo will **not** attempt to:

- clone the entire home directory
- copy browser profiles, cookies, sessions, or app databases
- copy Keychain data directly
- store SSH/GPG/cloud credentials in plaintext
- preserve `/usr/local` from Intel Macs as a binary artifact
- make Migration Assistant unnecessary for opaque GUI app state
- fully declarativize everything with Nix in v1
- support every Linux distro equally on day one

Nix/nix-darwin/Home Manager may become **Phase 2**, but not the initial delivery path.

---

## 3. Critical Security Findings from Init Audit

The existing Init repo must be sanitized before reuse.

### Must exclude from copy/import

- `key/` submodule and all private key material
- `.git/` and all submodule metadata
- `.DS_Store`, caches, generated runtime files
- raw `private_dot_ssh` private-key files if any appear beyond config templates
- raw `private_dot_gnupg/private-keys-v1.d` if ever present
- `private_dot_config/github-copilot/apps.json` because it contains OAuth credential material
- `private_Library/private_Application Support/io.datasette.llm/keys.json.tmpl` until rewritten to use safe placeholder/1Password references only
- any file matching secret patterns: `*credentials*`, `*token*`, `*secret*`, `*.pem`, `id_rsa`, `id_ed25519`, `*.key`, `known_hosts` unless explicitly classified safe

### Must rewrite before applying

- `private_dot_gnupg/gpg-agent.conf` currently hardcodes `/usr/local/bin/pinentry-mac`; it must template `brew --prefix` or OS-specific pinentry.
- `dot_zshrc.alan`, `dot_zshrc.tmpl`, and `dot_vimrc` contain `/usr/local` assumptions; these must become architecture/OS-aware.
- `bootstrap.sh` currently references `AlanSynn/Init`; it must reference the new repo name and support local source development.

### Secret policy

The repo may contain:

- non-secret SSH config templates
- 1Password item references
- age/SOPS-encrypted files only if explicitly required
- placeholder examples
- documentation for re-auth flows

The repo must not contain:

- actual OAuth tokens
- cloud credential JSON
- SSH/GPG private keys
- app session databases
- browser profile state

---

## 4. Proposed Repository Structure

```text
workstation-bootstrap/
├── masterplan.md
├── README.md
├── bootstrap.sh
├── Justfile
├── .gitignore
├── .gitattributes
├── .chezmoi.toml.tmpl
├── .chezmoiignore
├── .chezmoiexternal.toml
│
├── .chezmoiscripts/
│   ├── run_before_00-preflight.sh.tmpl
│   ├── run_onchange_10-install-packages.sh.tmpl
│   ├── run_once_20-setup-macos-defaults.sh.tmpl
│   ├── run_once_25-setup-linux-defaults.sh.tmpl
│   └── run_onchange_90-postinstall.sh.tmpl
│
├── dot_zshrc.tmpl
├── dot_zshenv.tmpl
├── dot_gitconfig.tmpl
├── dot_gitignore
├── dot_tmux.conf
├── dot_vimrc
├── dot_clang-format
├── dot_condarc
├── private_dot_config/
│   ├── git/ignore
│   ├── opencode/
│   ├── llm/
│   └── zed/
│
├── packages/
│   ├── Brewfile.common
│   ├── Brewfile.darwin
│   ├── Brewfile.linux
│   ├── mas.darwin.txt
│   ├── apt.ubuntu.txt
│   ├── npm-global.txt
│   ├── bun-global.txt
│   ├── uv-tools.txt
│   ├── cargo-tools.txt
│   └── fonts.txt
│
├── scripts/
│   ├── lib/
│   │   ├── log.sh
│   │   ├── os.sh
│   │   ├── paths.sh
│   │   └── secrets.sh
│   ├── audit-current-machine.sh
│   ├── sanitize-import.sh
│   ├── install-homebrew.sh
│   ├── install-system-packages.sh
│   ├── install-language-tools.sh
│   ├── install-vscode-extensions.sh
│   ├── setup-macos-defaults.sh
│   ├── setup-linux-defaults.sh
│   ├── verify-new-machine.sh
│   └── doctor.sh
│
├── docs/
│   ├── bootstrap-flow.md
│   ├── migration-checklist.md
│   ├── linux-support.md
│   ├── macos-support.md
│   ├── secrets-policy.md
│   ├── app-settings-policy.md
│   └── nix-phase2.md
│
├── inventories/
│   └── current-machine/
│       ├── brew-leaves.txt
│       ├── brew-casks.txt
│       ├── mas-list.txt
│       ├── vscode-extensions.txt
│       ├── npm-global.txt
│       ├── bun-global.txt
│       ├── uv-tools.txt
│       ├── cargo-tools.txt
│       └── sensitive-paths-redacted.txt
│
└── test/
    ├── docker/
    │   └── Dockerfile.ubuntu
    ├── smoke-bootstrap.sh
    └── verify-no-secrets.sh
```

---

## 5. Platform Strategy

### 5.1 macOS

macOS is the richest target and includes:

- Homebrew formulae
- Homebrew casks
- Mac App Store apps through `mas`
- macOS defaults
- Apple Silicon vs Intel path handling
- optional GUI app setting import/export
- Time Machine/Migration Assistant as fallback only

Rules:

- Apple Silicon Homebrew prefix: `/opt/homebrew`
- Intel Homebrew prefix: `/usr/local`
- never hardcode either in dotfiles; always use `brew --prefix` or helper functions
- casks and MAS entries live in macOS-only manifests
- `defaults write` scripts must be allowlisted, not generated from raw full plists

### 5.2 Linux

Linux support should be practical, not perfect.

Tier 1:

- Ubuntu via `apt-get`
- Fedora/Arch are explicitly deferred until Ubuntu is proven on a fresh target

Tier 2:

- generic Linux via Linuxbrew only

Linux responsibilities:

- install build prerequisites for Homebrew/Linuxbrew
- install zsh/git/curl/ca-certificates/procps/locales
- install chezmoi, just, gh, tmux, neovim
- apply shared dotfiles
- skip macOS-only app/defaults/MAS/cask flows
- use `systemd --user` or documented manual setup where launch agents differ

### 5.3 Shared layer

Shared across macOS and Linux:

- shell configuration
- git config
- vim/tmux/nvim base config
- common CLI tools via Homebrew/Linuxbrew where appropriate
- language tool manifests: Node, Python/uv, Rust, Go
- AI tool config templates when non-secret
- docs and verification scripts

---

## 6. Package Management Design

### 6.1 Brewfile split

Use layered Brewfiles:

```text
packages/Brewfile.common   # CLI tools that work on macOS/Linuxbrew
packages/Brewfile.darwin   # casks, mac-only formulae, pinentry-mac, mas
packages/Brewfile.linux    # linuxbrew formulae only
```

Generated root `Brewfile` is optional. Better: have scripts call the right layers:

```bash
brew bundle --file packages/Brewfile.common
if is_macos; then brew bundle --file packages/Brewfile.darwin; fi
if is_linux; then brew bundle --file packages/Brewfile.linux; fi
```

### 6.2 Native Linux packages

Linux bootstrap needs native prerequisites before Linuxbrew:

```text
packages/apt.ubuntu.txt
```

These should include only prerequisites and tools better installed natively.

### 6.3 Mac App Store

Use `packages/mas.darwin.txt` with lines:

```text
497799835 Xcode
409183694 Keynote
...
```

Install script converts to:

```bash
mas install <id>
```

`mas` installation must be non-fatal because App Store login is manual/account-bound.

### 6.4 Language tools

Separate from OS packages:

- `packages/npm-global.txt`
- `packages/bun-global.txt`
- `packages/uv-tools.txt`
- `packages/cargo-tools.txt`

Installers must be idempotent and tolerate missing runtimes.

---

## 7. Chezmoi Design

### 7.1 Machine data model

`.chezmoi.toml.tmpl` should expose:

```toml
[data]
profile = "personal"        # personal | work | minimal | ci
os = "darwin"               # from chezmoi
arch = "arm64"              # arm64 | amd64/x86_64
is_macos = true
is_linux = false
is_apple_silicon = true
is_intel_mac = false
brew_prefix = "/opt/homebrew"
install_gui_apps = true
install_ai_tools = true
install_research_tools = true
secrets_provider = "1password" # 1password | age | none
```

### 7.2 Template rules

- All `/usr/local` references must be replaced with `{{ .brew_prefix }}` or runtime shell helpers.
- macOS-only shell paths must be behind `is_macos` checks.
- Linux-only completions/services must be behind `is_linux` checks.
- Work/personal split must not rely only on username; support `--data profile=...`.

### 7.3 Externals

Keep useful externals:

- oh-my-zsh
- pure prompt
- zsh syntax highlighting
- zsh autosuggestions
- tmux plugin manager
- nvim config if still desired

But pin or document refresh policy. Avoid externals that pull private/unreviewed state.

---

## 8. Init Import Strategy

### 8.1 Do not copy directly with `cp -a`

Use a sanitized import script.

Initial safe import allowlist:

```text
.chezmoi.toml.tmpl
.chezmoiignore
.chezmoiexternal.toml
.chezmoiscripts/
Brewfile
Justfile
README.md
bootstrap.sh
dot_zshrc.tmpl
dot_zshrc.alan
dot_shell.alan
dot_gitconfig.tmpl
dot_gitignore
dot_vimrc
dot_tmux.conf
dot_tmux.conf.local
dot_clang-format
dot_condarc
dot_tigrc
private_dot_config/git/ignore
private_dot_config/opencode/
private_dot_config/llm/   # templates only after review
private_dot_claude/       # only after token scan and runtime-cache pruning
private_dot_ssh/config.tmpl
private_dot_gnupg/gpg-agent.conf
```

Hard exclude:

```text
.git/
.gitmodules
key/
z/.git/
.DS_Store
app-configs/franz/
rcfiles/
homebrew/ legacy duplicates
install.sh legacy script
private_dot_config/github-copilot/apps.json
private_Library/**/keys.json*
**/*.pem
**/id_rsa*
**/id_ed25519*
**/*credentials*
**/*token*
**/*secret*
```

### 8.2 Import workflow

1. Create git repo in current workspace.
2. Copy masterplan and scaffolding.
3. Run `scripts/sanitize-import.sh --from /Users/alansynn/Workspace/src/github.com/AlanSynn/Init --dry-run`.
4. Review generated import manifest.
5. Run sanitized import.
6. Run secret scan.
7. Commit only after no-secret verification passes.

---

## 9. Bootstrap Flow

### 9.1 User-facing commands

```bash
./bootstrap.sh --tier minimal
./bootstrap.sh --tier cli
./bootstrap.sh --tier full
./bootstrap.sh --profile personal --os auto
./bootstrap.sh --dry-run
```

Tiers:

- `minimal`: install git/chezmoi/just only, apply core dotfiles
- `cli`: minimal + common CLI packages + shell/tmux/nvim
- `full`: cli + GUI apps on macOS + language tools + app config templates
- `ci`: no GUI, no secrets, no shell change, deterministic smoke test

### 9.2 Internal phases

```text
00 preflight
10 install base package manager
20 install core packages
30 initialize/apply chezmoi
40 install language tools
50 apply OS defaults
60 optional app settings
70 verify
```

### 9.3 Safety defaults

- dry-run mode available for all destructive-looking operations
- no `brew bundle cleanup` unless explicitly requested
- no shell change unless confirmed by flag or safe default
- no App Store install treated as hard failure
- no cloud login automation beyond printing instructions

---

## 10. Verification and Tests

### 10.1 Local verification

```bash
just fmt
just lint
just secret-scan
just shellcheck
just chezmoi-dry-run
just verify
```

### 10.2 macOS verification

- `brew bundle check` for common + darwin Brewfiles
- `mas list` compares expected IDs where possible
- `chezmoi diff` clean or expected
- `defaults read` checks for allowlisted defaults
- `zsh -lic 'echo ok'`
- `tmux -V`, `nvim --version`, `git config --list --show-origin`

### 10.3 Linux verification

Use Docker smoke tests:

- Ubuntu container only for the first Linux pass

Checks:

- bootstrap minimal in CI mode
- package prerequisite installer dry-run
- chezmoi template rendering for Linux
- shell starts without macOS-only path errors

### 10.4 Secret verification

Required before first commit and every CI run:

```bash
scripts/verify-no-secrets.sh
```

Checks:

- known token regexes
- private key headers
- `.pem` files
- cloud credential JSON names
- GitHub/Copilot OAuth files
- accidental `.ssh`, `.gnupg`, `.aws`, `.kube`, `.docker` data

---

## 11. Milestones

### Milestone A: Planning artifacts

Deliverables:

- `masterplan.md`
- `.omx/context/...`
- `.omx/plans/prd-*.md`
- `.omx/plans/test-spec-*.md`

Exit criteria:

- plan identifies copy/sanitize strategy
- macOS/Linux platform decisions are explicit
- security exclusions are explicit

### Milestone B: New repo skeleton

Deliverables:

- initialized git repo
- README, bootstrap, Justfile, docs skeleton
- package manifest directories
- scripts skeleton

Exit criteria:

- `just --list` works
- `./bootstrap.sh --dry-run` works
- no secrets in git

### Milestone C: Sanitized Init import

Deliverables:

- safe dotfiles copied from Init
- legacy folders excluded or moved to `archive/` only if safe
- `/usr/local` hardcoding replaced
- GitHub Copilot token file excluded

Exit criteria:

- secret scan passes
- `chezmoi diff --source . --dry-run` or equivalent safe check works
- imported files have clear rationale

### Milestone D: Current machine inventory

Deliverables:

- fresh Brewfile layers
- MAS list
- language tool manifests
- VS Code extension manifest
- sensitive path inventory redacted

Exit criteria:

- manifests are curated, not raw dumps
- macOS-only vs Linux-compatible packages separated

### Milestone E: Cross-platform bootstrap

Deliverables:

- macOS bootstrap path
- Linux bootstrap path for Ubuntu only in the first pass
- package installer logic
- postinstall hooks

Exit criteria:

- macOS dry-run passes
- Linux Docker smoke tests pass

### Milestone F: Review and hardening

Deliverables:

- docs completed
- CI added if desired
- code-review findings fixed
- Lore-format final commits

Exit criteria:

- clean code review
- no secrets
- bootstrap verified

---

## 12. Autopilot Execution Plan

The requested `$autopilot` loop should proceed as follows after this plan-first step.

### Phase 1: ralplan

Current phase. Produce:

- `masterplan.md`
- PRD artifact
- test-spec artifact

### Phase 2: ralph

Implement from approved planning artifacts:

1. initialize new repo skeleton
2. create scripts/docs directories
3. implement sanitize import script
4. import safe Init files
5. split package manifests
6. create dry-run bootstrap
7. add verification/secret-scan script
8. run checks

### Phase 3: code-review

Review for:

- secret leakage
- unsafe bootstrap operations
- macOS/Linux branching correctness
- `/usr/local` hardcoding
- stale Init references
- documentation clarity
- test coverage and smoke checks

If review is not clean, return to ralplan with findings.

---

## 13. Immediate Next Step After This File

Create `.omx/plans/prd-init-v2-cross-platform-bootstrap.md` and `.omx/plans/test-spec-init-v2-cross-platform-bootstrap.md` from this plan, then begin implementation only after the planning artifacts are in place.
