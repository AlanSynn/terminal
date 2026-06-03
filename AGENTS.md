# AGENTS.md — workstation-bootstrap

This file is the operating contract for agents working in this repository. It
applies to the repo root and all child paths unless a deeper `AGENTS.md`
overrides it.

## Mission

Build and maintain Alan's macOS + Ubuntu workstation bootstrap repo so a new
machine can reproduce the terminal/dotfile/tooling environment with one
friendly command:

```bash
./install.sh
```

When `just` is already installed, plain `just` is an equivalent shortcut to
`./install.sh`; keep `just list` as the command-discovery path.

The human first-run experience must stay simple and menu-driven. The lower-level
engine, manifests, tests, and docs exist to make that one command safe,
auditable, and reproducible.

## Core boundaries

- `install.sh` is the friendly interface. Keep it TTY/menu-first, dry-run by
  default, and free of normal user-facing install flags.
- `bootstrap.sh` is the deterministic automation engine. Use it for CI,
  tests, and scripted/debug flows.
- Linux support means Ubuntu only for now. Do not broaden Fedora/Arch/Nix scope
  unless the user explicitly asks.
- `packages/` is the canonical install manifest surface.
- `inventories/current-machine/` is observed source-machine evidence. Do not
  treat inventory snapshots as automatic install requirements.
- `.omx/` is runtime state and is ignored. Do not treat it as source material
  for commits except when citing workflow evidence.

## Cleanup and change discipline

- Preserve behavior first. Before cleanup/refactor work, run or add the
  narrowest regression check that proves the current behavior.
- Prefer deletion, reuse, and simpler boundaries before new abstractions.
- Keep diffs small and scoped. Avoid broad rewrites of bootstrap, dotfiles, and
  docs in one commit.
- Do not add dependencies unless the user explicitly asks or there is a clear
  safety/reproducibility reason.
- If something looks duplicated, classify it before deleting:
  - intentional: `inventories/current-machine/*` vs `packages/*`
  - wrapper/engine boundary: `install.sh` vs `bootstrap.sh`
  - test convenience vs real implementation
  - historical planning vs live docs
- Keep legacy Init import helpers (`scripts/sanitize-import.sh`, `import-init*`)
  until the repo has been proven on real macOS and Ubuntu apply runs, unless the
  user explicitly retires them.

## Terminal parity rules

- Treat terminal dotfiles as high-sensitivity behavior:
  - `dot_zshrc.tmpl`
  - `dot_zshrc.alan.tmpl`
  - `dot_zshenv.tmpl`
  - `dot_shell.alan`
  - `dot_tmux.conf`
  - `dot_tmux.conf.local`
  - `dot_gitconfig`
  - `dot_gitignore`
  - `private_dot_ssh/**`
  - `private_dot_gnupg/**`
- For terminal/dotfile changes, run template/syntax checks and, when on the
  source machine, `test/terminal-parity.sh`.
- Do not remove shell aliases/functions/settings as "cleanup" without proving
  they are unused or intentionally retired.
- Keep generated or secret-bearing runtime files out of git.

## Security and privacy rules

- Never commit private keys, tokens, service account files, raw credentials, or
  password-manager exports.
- Prefer templates, placeholders, and password-manager references over
  plaintext secret values.
- Keep SSH host/user/routing metadata in private overlays when possible.
- Treat this repo as private by default, but keep it resilient against accidental
  exposure.
- Before commits that touch secrets, SSH, backup, inventory, or public-readiness
  surfaces, run:

```bash
scripts/verify-no-secrets.sh
just private-risk-audit
just public-audit
```

## Backup and migration rules

- Large user directories (`Downloads`, `Documents`, `Workspace`, media, etc.)
  are not managed by git or chezmoi.
- Use `backup/user-dirs.json` plus `scripts/backup-user-dirs.sh` and
  `scripts/restore-user-dirs.sh` for external-drive migration.
- Always dry-run backup/restore first.
- Assume backup destinations may contain sensitive data; prefer encrypted
  APFS/LUKS/FileVault-protected drives and physical custody.

## Verification commands

Use the smallest check that proves the claim, then widen when risk is higher.

Common checks:

```bash
bash -n install.sh bootstrap.sh scripts/*.sh scripts/lib/*.sh test/*.sh
test/installer-smoke.sh
test/smoke-bootstrap.sh
scripts/verify-no-secrets.sh
just verify
```

Additional checks by change type:

```bash
test/manifest-consistency.sh        # package/app/extension manifest changes
test/backup-plan-dry-run.sh         # backup/restore changes
test/terminal-parity.sh             # terminal dotfile changes on source Mac
just public-audit                   # public/private surface changes
just private-risk-audit             # operational security changes
```

Expected non-blocking warnings on the current source machine may include
optional missing `shellcheck`, `chezmoi init` guidance, and incomplete local
Homebrew bundle state. Report them, but do not hide them.

## Documentation rules

- Keep `README.md` as the polished front door.
- Keep `docs/bootstrap-flow.md` as the implementation flow reference.
- Keep `docs/repo-surface-review.md` as the source of truth for retained legacy
  surfaces and cleanup candidates.
- Treat `masterplan.md` as historical Init v2 planning context, not the daily
  guide.
- If changing first-run behavior, update both README and the relevant docs.

## Commit protocol

Use Lore-format commit messages:

```text
<intent line: why the change was made, not what changed>

Constraint: <external constraint that shaped the decision>
Rejected: <alternative considered> | <reason for rejection>
Confidence: <low|medium|high>
Scope-risk: <narrow|moderate|broad>
Directive: <forward-looking warning for future modifiers>
Tested: <what was verified>
Not-tested: <known gaps in verification>
```

Report final results with changed files, simplifications, verification evidence,
and remaining risks.
