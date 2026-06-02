# Repo Surface Review

This review answers whether workstation-bootstrap currently has unnecessary legacy code, strange scripts, or too much documentation.

## Verdict

The repo is not fundamentally bloated, but its **first-run surface was too noisy**: README mixed quick start, migration policy, backup layout, terminal parity, and verification details. The right cleanup is to make `install.sh` + README the polished front door and keep detailed docs as references.

## Keep as first-class surfaces

| Surface | Why keep |
| --- | --- |
| `install.sh` | Interface-first entrypoint: one command, numbered menu choices, dry-run default, no normal install flags. |
| `bootstrap.sh` | Deterministic install engine used by the wrapper and scripts. |
| `Justfile` | Discoverable local task index. |
| `packages/` | Declarative install manifests for Homebrew, MAS, apt, VS Code, npm/bun/uv/cargo. |
| `.chezmoi*`, `dot_*`, `private_dot_*` | Core terminal parity and dotfile render source. |
| `scripts/install-*`, `scripts/setup-*` | Stage-specific install implementation. |
| `scripts/verify-*`, audit scripts, `test/` | Safety and regression checks. |
| `backup/`, `scripts/backup-user-dirs.sh`, `scripts/restore-user-dirs.sh` | External-drive emergency migration flow. |

## Keep, but do not feature in quick start

| Surface | Classification | Reason |
| --- | --- | --- |
| `masterplan.md` | Historical planning record | Useful context from Init v2 design, but too long for daily use. README should point to it only as history. |
| `scripts/sanitize-import.sh` | Legacy/re-import utility | Useful if importing from old Init again; not part of normal install. |
| `import-init*` Just recipes | Legacy/re-import utility | Hide below first-run workflow; keep until the new repo has been proven on real machines. |
| `docs/nix-phase2.md` | Deferred note | Tiny and harmless; keep as explicit non-goal until Nix is revisited. |
| `docs/linux-support.md`, `docs/macos-support.md` | Platform reference shards | Small, useful scope boundaries; possible future consolidation. |
| `docs/public-repo-readiness.md`, `docs/private-repo-security-review.md`, `docs/secrets-policy.md` | Security policy | Important because public/private safety is not obvious from README alone. |

## Future cleanup candidates

Do not delete these in this pass; revisit after a real macOS/Ubuntu apply:

1. Archive `masterplan.md` under `docs/history/` once the repo is proven.
2. Remove or archive `scripts/sanitize-import.sh` and `import-init*` after no more Init imports are expected.
3. Consolidate tiny platform notes into `docs/bootstrap-flow.md` if they stop changing.
4. Decide whether Nix remains a phase-2 note or should be removed entirely.
5. Add a generated command reference if `Justfile` grows further.

## Why not delete more now?

- The repo is still migration-critical; deleting provenance or import safety tools too early makes recovery harder.
- Security docs are intentionally separate because public-readiness, private operational risk, and secret policy answer different failure modes.
- Backup docs are longer because external-drive mistakes can destroy or leak user data.

## UX decision

The polished path is:

```bash
./install.sh
```

Advanced automation/debugging can still run the lower-level engine:

```bash
./bootstrap.sh --dry-run --profile personal --tier cli
just --list
```

This keeps the first-run experience menu-driven while preserving deterministic lower-level commands for tests and CI.
