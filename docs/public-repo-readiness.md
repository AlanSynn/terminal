# Public Repository Readiness

This repo can be prepared for public release, but it is **not anonymous as-is**. Current scans show no high-confidence plaintext credentials in the tracked tree or git history, yet several privacy and infrastructure metadata surfaces remain.

## Current audit result

Run:

```bash
just public-audit
```

Current classification:

| Area | Status | Public-release meaning |
| --- | --- | --- |
| Plaintext API keys, private keys, OAuth tokens | Clear in current scan | No high-confidence secret found in tracked files or history. |
| Git identity | Review | Publicly reveals the configured author name/email and signing key id. |
| Absolute local paths | Review | Reveals local username and some machine-specific install paths. Prefer template variables for a polished public repo. |
| SSH configs | Review/high privacy | Reveals institution/cloud account aliases, host metadata, and usernames. No private keys are tracked, but these files are better as a private overlay if anonymity matters. |
| Backup manifests | Review | Includes user directory names that can reveal affiliations or cloud-storage layout. |
| App/package inventories | Review | Exposes installed apps, paid GUI apps, VS Code extensions, and AI tooling choices. Usually acceptable for personal dotfiles, not anonymous. |
| Password-manager references | Acceptable with review | `op://` and 1Password references are not secrets by themselves, but they reveal secret item naming conventions if made too specific. |
| LLM/opencode configs | Review | No keys found, but provider/plugin choices and model aliases are public metadata. |

## Recommended public strategies

1. **Best balance: public core + private overlay**
   - Keep this repo public for bootstrap scripts, package manifests, generic dotfiles, backup tooling, and docs.
   - Move personal SSH configs, git identity, institution-specific backup entries, and local path-heavy shell customizations into a separate private chezmoi source or included private repo.

2. **Sanitized public branch**
   - Keep the current repo private as the source of truth.
   - Publish a generated/sanitized branch that removes institution/account metadata and replaces personal paths with template variables.

3. **Encrypted private files in public repo**
   - Use chezmoi encryption with age/SOPS/1Password for private SSH includes and identity files.
   - Good when a single public repo is required, but still reveals encrypted file names and structure.

4. **Private repo only**
   - Safest if exact terminal parity, SSH routing, and app inventories matter more than public reuse.

## Before making the repo public

Minimum gate:

```bash
just public-audit
scripts/verify-no-secrets.sh
git log --oneline --all
```

If you want a stricter anonymous/public template, run:

```bash
just public-audit-strict
```

`public-audit-strict` intentionally fails while privacy metadata remains. Passing strict mode means the repo is closer to a reusable public template, not just a personal public dotfiles repo.

## If a real secret is ever found

1. Treat it as exposed if it was committed, even if later deleted.
2. Rotate/revoke the credential first.
3. Rewrite history only after deciding whether collaborators/forks exist.
4. Re-run `just public-audit` and `scripts/verify-no-secrets.sh` after cleanup.
