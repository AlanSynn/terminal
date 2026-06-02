# Private Repository Security Review

Keeping this repository private removes the broad public reconnaissance problem, but it does **not** eliminate security-incident risk. A private workstation-bootstrap repo is still high impact because it can install software, configure shells, point to SSH infrastructure, and drive large backups.

Run:

```bash
just private-risk-audit
```

For a stricter gate that fails while high-risk findings remain:

```bash
just private-risk-audit-strict
```

## Current risk classification

| Severity | Area | Why it can cause an incident | Current status / mitigation |
| --- | --- | --- | --- |
| High | Plaintext git credential helper | `credential.helper = store` can create `~/.git-credentials` with plaintext HTTPS credentials/PATs after bootstrap. | Prefer `osxkeychain`, Git Credential Manager, libsecret, cache, or `gh auth`; remove/avoid backing up `~/.git-credentials`. |
| High | External-drive backup loss | Backup mirrors user directories. Excludes block common credential files, but documents/downloads/workspaces can still contain sensitive papers, datasets, tokens in unusual filenames, or proprietary code. | Use encrypted APFS/LUKS/FileVault-protected drives, physical custody, and dry-run review before apply. |
| High | Runtime bootstrap supply chain | Homebrew installer and package managers execute upstream code at setup time. A private repo does not protect against upstream or network compromise. | Run on a reviewed network/device, use official sources, pin versions/checksums for critical tools, and test in disposable VM first. |
| Medium | Global API key exports | Keys exported in shell startup are inherited by every child process and can leak through logs, plugins, crash reports, or `env` dumps. | Prefer `op run`, scoped wrappers, or dir-local secret injection for sensitive commands. |
| Medium | SSH/agent metadata and socket use | Private repo leak reveals host/user map; local compromise can abuse SSH agent/control sockets if permissions are weak. | Keep SSH includes in private overlay or encrypted source; use hardware-backed keys/confirmation for high-value hosts; keep `~/.ssh` and socket dirs mode 700. |
| Medium | Unpinned global language tools | npm/bun/uv/cargo global installs are mostly unversioned and may run install-time code. | Pin critical tools or promote through a reviewed allowlist/lock process. |
| Medium | Chezmoi externals without checksums | Externals are commit-pinned but not checksum-pinned. | Add checksums where supported or vendor reviewed snapshots for high-assurance rebuilds. |
| Medium | Shell startup eval/source | Shell startup evaluates tool output and sources optional local config. | Audit shell startup changes, keep autoenv-style features disabled unless needed, and avoid untrusted repos in secret-rich shells. |
| Low | Backup metadata sync `--delete` | `--delete` is used only for inventory metadata, not user data. | Keep tests and never reuse this pattern for user data directories. |

## Highest-priority actions

1. Replace or remove `credential.helper = store` before using HTTPS credentials on a real machine.
2. Treat the external backup drive as a sensitive asset: encrypted filesystem, physical custody, no untrusted hosts.
3. Do not run `./bootstrap.sh --tier full` on a real machine unless `just private-risk-audit` and dry-runs are reviewed.
4. Scope API keys to commands instead of exporting them globally when possible.
5. Move institution/cloud SSH includes into a private overlay or encrypted chezmoi source if repo access expands beyond personal devices.

## What private repo compromise would enable

If an attacker gets read access to this private repo, they still do not get private keys or API tokens from the current scan. They do get:

- bootstrap scripts that show what software and auth surfaces will be installed;
- SSH host/user naming and institution/cloud routing metadata;
- package/tooling choices useful for supply-chain targeting;
- backup layout and likely high-value user directories;
- shell startup patterns showing where API keys may be present at runtime.

That is enough for targeted phishing, dependency confusion/social engineering, or local post-compromise acceleration. Therefore the repo should remain private even if public audit is clear, unless a sanitized public branch or private overlay is used.

## Verification before private apply

Minimum:

```bash
scripts/verify-no-secrets.sh
just public-audit
just private-risk-audit
./bootstrap.sh --dry-run --tier full
```

For stricter reviews, expect `just private-risk-audit-strict` to fail until high-risk findings are fixed. If you manually accept current high-risk findings, keep that decision in report-mode review notes; strict mode has no acceptance registry yet.
