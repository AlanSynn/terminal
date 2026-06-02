#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/log.sh
. "$ROOT_DIR/scripts/lib/log.sh"

mode="report"
case "${1:-}" in
  --report|"") mode="report" ;;
  --strict) mode="strict" ;;
  --self-test) mode="self-test" ;;
  --help|-h)
    cat <<'USAGE'
Usage: scripts/audit-private-risk.sh [--report|--strict|--self-test]

Audits risks that can still cause a security incident even when the repository is private.
The audit reports file/line/reason only and never prints matched secret values.

--report     Warn about private-repo operational risks; fail only on secret-scan failure.
--strict     Fail when HIGH private-repo operational risks are present.
--self-test  Run audit logic regression tests without scanning repository content.
USAGE
    exit 0
    ;;
  *) die "unknown option: $1" ;;
esac

cd "$ROOT_DIR"
if [[ "$mode" != "self-test" ]]; then
  "$ROOT_DIR/scripts/verify-no-secrets.sh" >/dev/null
fi

set +e
python3 - "$mode" <<'PY'
import pathlib
import re
import sys
from collections import defaultdict

mode = sys.argv[1]
root = pathlib.Path.cwd()

checks = [
    {
        "id": "plaintext-git-credential-helper",
        "severity": "HIGH",
        "category": "local-credential-storage",
        "path": "dot_gitconfig",
        "pattern": re.compile(r"^\s*helper\s*=\s*store\b.*$", re.M),
        "risk": "Git credential.helper store can persist HTTPS credentials/PATs in plaintext under ~/.git-credentials after bootstrap.",
        "mitigation": "Prefer osxkeychain/Git Credential Manager/libsecret/cache, or omit this setting and re-auth through gh/op.",
    },
    {
        "id": "global-api-key-shell-export",
        "severity": "MEDIUM",
        "category": "secret-runtime-propagation",
        "path": "dot_zshrc.alan.tmpl",
        "pattern": re.compile(r"^export\s+(OPENAI_API_KEY|GOOGLE_API_KEY|POLLINATIONS_API_KEY)=", re.M),
        "risk": "API keys become inherited by all child processes from interactive shells and can leak through debug logs, env dumps, plugins, or crash reports.",
        "mitigation": "Prefer scoped `op run`, dir-local secret injection, or per-command wrappers for sensitive keys.",
    },
    {
        "id": "private-ssh-routing-metadata",
        "severity": "MEDIUM",
        "category": "repo-compromise-recon",
        "path": "private_dot_ssh/config.tmpl",
        "pattern": re.compile(r"^\s*(Include|Host|HostName|User|IdentityFile|IdentityAgent|ControlMaster|ControlPath)\s+", re.M),
        "risk": "A private repo compromise reveals SSH routing, identity-agent usage, and host/user metadata useful for targeted attacks.",
        "mitigation": "Move institution/cloud SSH includes to a private overlay or encrypted chezmoi source; keep ~/.ssh and control socket directories mode 700.",
    },
    {
        "id": "institution-ssh-include",
        "severity": "MEDIUM",
        "category": "repo-compromise-recon",
        "path": "private_dot_ssh/configs/gatech/gatech",
        "pattern": re.compile(r"^\s*(Host|HostName|User|IdentityFile)\s+", re.M),
        "risk": "Institution-specific SSH aliases and key paths create a reconnaissance map if the private repo is leaked.",
        "mitigation": "Keep this in a private overlay; use hardware-backed keys and key confirmation for high-value hosts.",
    },
    {
        "id": "institution-ssh-include",
        "severity": "MEDIUM",
        "category": "repo-compromise-recon",
        "path": "private_dot_ssh/configs/gatech/nersc",
        "pattern": re.compile(r"^\s*(Host|HostName|User|IdentityFile)\s+", re.M),
        "risk": "Institution-specific SSH aliases and usernames create a reconnaissance map if the private repo is leaked.",
        "mitigation": "Keep this in a private overlay; rotate exposed usernames only if paired with other credential compromise.",
    },
    {
        "id": "cloud-ssh-wildcard",
        "severity": "LOW",
        "category": "repo-compromise-recon",
        "path": "private_dot_ssh/configs/personal/aws",
        "pattern": re.compile(r"^\s*Host\s+aws-", re.M),
        "risk": "Cloud SSH naming conventions expose personal infrastructure assumptions.",
        "mitigation": "Prefer private overlay if repo sharing expands beyond trusted devices.",
    },
    {
        "id": "remote-installer-curl-bash",
        "severity": "HIGH",
        "category": "bootstrap-supply-chain",
        "path": "scripts/install-homebrew.sh",
        "pattern": re.compile(r"^NONINTERACTIVE=1\s+bash\s+-c\s+\"\$\(curl\s+-fsSL", re.M),
        "risk": "Bootstrap executes the current Homebrew installer fetched at runtime; a network/upstream compromise affects new machines.",
        "mitigation": "Run only after review, prefer official TLS source, and consider pinning/checksum verification for high-assurance rebuilds.",
    },
    {
        "id": "global-language-package-install",
        "severity": "MEDIUM",
        "category": "bootstrap-supply-chain",
        "path": "scripts/install-language-tools.sh",
        "pattern": re.compile(r"(npm install -g|bun add -g|uv tool install|cargo install)"),
        "risk": "Global package installs execute package-manager resolution and install scripts at bootstrap time.",
        "mitigation": "Pin versions for critical tools, review maintainer trust, and re-run on disposable VM before real machines.",
    },
    {
        "id": "chezmoi-external-no-checksum",
        "severity": "MEDIUM",
        "category": "bootstrap-supply-chain",
        "path": ".chezmoiexternal.toml",
        "pattern": re.compile(r"url\s*=\s*\"https://github.com/.+archive/.+\.tar\.gz\"", re.M),
        "risk": "External archives are commit-pinned but not checksum-pinned, so trust still depends on GitHub/archive delivery and chezmoi cache integrity.",
        "mitigation": "Add checksum verification where supported or vendor reviewed snapshots for high-assurance environments.",
    },
    {
        "id": "auto-source-local-shell-code",
        "severity": "MEDIUM",
        "category": "shell-execution",
        "path": "dot_zshrc.alan.tmpl",
        "pattern": re.compile(r"(source \$HOME/\.autoenv/activate\.sh|source ~/\.fzf|eval \"\$\(|eval \$__mamba_setup)", re.M),
        "risk": "Shell startup evaluates/sources local tool output and optional autoenv-style code; a compromised local tool or malicious project config can run in every shell.",
        "mitigation": "Keep autoenv disabled unless needed, audit shell startup changes, and avoid opening untrusted repos with secret-rich shells.",
    },
    {
        "id": "external-drive-backup-sensitive-data",
        "severity": "HIGH",
        "category": "backup-loss",
        "path": "backup/user-dirs.json",
        "pattern": re.compile(r'"source"\s*:\s*"~/(Desktop|Documents|Downloads|Workspace|Pictures|Movies|Music)/"'),
        "risk": "Backup mirrors large user directories to an external drive; excludes remove common credential files but cannot classify every sensitive document or dataset.",
        "mitigation": "Require encrypted APFS/LUKS/FileVault-protected drives, physical custody, and dry-run review before apply.",
    },
    {
        "id": "backup-metadata-rsync-delete",
        "severity": "LOW",
        "category": "backup-integrity",
        "path": "scripts/backup-user-dirs.sh",
        "pattern": re.compile(r"rsync -a --delete \"\$ROOT_DIR/inventories/current-machine/\""),
        "risk": "Backup metadata sync uses --delete for inventory metadata only; accidental path bugs could remove metadata snapshots.",
        "mitigation": "Keep marker/path checks and tests; do not reuse this pattern for user data directories.",
    },
]

manifest_version_files = [
    ("packages/npm-global.txt", "npm-global-unpinned", "MEDIUM", "npm global packages are unversioned or use mutable/range resolution."),
    ("packages/bun-global.txt", "bun-global-unpinned", "MEDIUM", "bun global packages are unversioned or use mutable/range resolution."),
    ("packages/uv-tools.txt", "uv-tool-unpinned", "MEDIUM", "uv tools are unversioned."),
    ("packages/cargo-tools.txt", "cargo-tool-unpinned", "MEDIUM", "cargo tools are unversioned."),
]

EXACT_SEMVER = re.compile(r"^v?\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$")
MUTABLE_NPM_TAGS = {
    "latest", "next", "canary", "beta", "alpha", "rc", "experimental",
    "nightly", "dev", "stable", "lts", "insiders", "snapshot", "*", "",
}

findings = []

def add_finding(check, lines):
    unique_lines = sorted(set(lines))
    findings.append({
        "severity": check["severity"],
        "id": check["id"],
        "category": check["category"],
        "file": check["path"],
        "lines": unique_lines,
        "risk": check["risk"],
        "mitigation": check["mitigation"],
    })

def npm_or_bun_spec_pinned(line):
    token = line.split()[0]
    if token.startswith("@"):
        _, slash, package_tail = token.partition("/")
        if not slash or "@" not in package_tail:
            return False
        suffix = package_tail.rsplit("@", 1)[1].strip().lower()
    else:
        if "@" not in token:
            return False
        suffix = token.rsplit("@", 1)[1].strip().lower()
    if suffix in MUTABLE_NPM_TAGS:
        return False
    return bool(EXACT_SEMVER.fullmatch(suffix))

def package_spec_pinned(rel, line):
    if rel in ("packages/npm-global.txt", "packages/bun-global.txt"):
        return npm_or_bun_spec_pinned(line)
    if rel.endswith("cargo-tools.txt"):
        return "@" in line or " --version " in line
    return any(token in line for token in ("==", "~=", ">=", "<="))

def run_self_test():
    cases = [
        ("packages/npm-global.txt", "@scope/pkg", False),
        ("packages/npm-global.txt", "@scope/pkg@1.2.3", True),
        ("packages/npm-global.txt", "@scope/pkg@1.2.3-beta.1", True),
        ("packages/npm-global.txt", "@scope/pkg@latest", False),
        ("packages/npm-global.txt", "@scope/pkg@next", False),
        ("packages/npm-global.txt", "@scope/pkg@canary", False),
        ("packages/npm-global.txt", "pkg", False),
        ("packages/npm-global.txt", "pkg@1.2.3", True),
        ("packages/npm-global.txt", "pkg@latest", False),
        ("packages/npm-global.txt", "pkg@next", False),
        ("packages/npm-global.txt", "pkg@^1.2.3", False),
        ("packages/npm-global.txt", "pkg@~1.2.3", False),
        ("packages/npm-global.txt", "pkg@>=1.2.3", False),
        ("packages/npm-global.txt", "pkg@*", False),
        ("packages/bun-global.txt", "@scope/pkg", False),
        ("packages/bun-global.txt", "@scope/pkg@1.2.3", True),
    ]
    failures = []
    for rel, line, expected in cases:
        actual = package_spec_pinned(rel, line)
        if actual != expected:
            failures.append((rel, line, expected, actual))
    if failures:
        print("[ERROR] private risk audit self-test failed")
        for rel, line, expected, actual in failures:
            print(f"  - {rel}: expected {expected} got {actual} for synthetic spec {line!r}")
        sys.exit(2)
    print("[OK] private risk audit self-test passed")

if mode == "self-test":
    run_self_test()
    sys.exit(0)

for check in checks:
    path = root / check["path"]
    if not path.exists():
        continue
    text = path.read_text(encoding="utf-8", errors="ignore")
    lines = [text[: match.start()].count("\n") + 1 for match in check["pattern"].finditer(text)]
    if lines:
        add_finding(check, lines)

for rel, finding_id, severity, risk in manifest_version_files:
    path = root / rel
    if not path.exists():
        continue
    unpinned_lines = []
    for idx, raw in enumerate(path.read_text(encoding="utf-8", errors="ignore").splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        # Accept exact-version syntaxes for npm/bun; warn on mutable tags/ranges.
        if not package_spec_pinned(rel, line):
            unpinned_lines.append(idx)
    if unpinned_lines:
        findings.append({
            "severity": severity,
            "id": finding_id,
            "category": "bootstrap-supply-chain",
            "file": rel,
            "lines": unpinned_lines,
            "risk": risk,
            "mitigation": "Pin versions for critical bootstrap tools or promote through a reviewed lock/allowlist process.",
        })

sev_order = {"HIGH": 0, "MEDIUM": 1, "LOW": 2}
findings.sort(key=lambda f: (sev_order.get(f["severity"], 9), f["category"], f["file"], f["lines"][0], f["id"]))
counts = defaultdict(int)
for finding in findings:
    counts[finding["severity"]] += 1

def line_summary(lines):
    if len(lines) <= 6:
        return ",".join(str(line) for line in lines)
    shown = ",".join(str(line) for line in lines[:6])
    return f"{shown},+{len(lines) - 6} more"

print(f"[INFO] private-repo operational risk findings: HIGH={counts['HIGH']} MEDIUM={counts['MEDIUM']} LOW={counts['LOW']}")
if not findings:
    print("[OK] no private-repo operational risk findings")
else:
    last = None
    for finding in findings:
        header = f"{finding['severity']} {finding['category']}"
        if header != last:
            print(f"\n[{finding['severity']}] {finding['category']}")
            last = header
        lines = line_summary(finding["lines"])
        match_count = len(finding["lines"])
        match_suffix = f" (matches={match_count}, lines={lines})" if match_count > 1 else ""
        print(f"  - {finding['file']}:{finding['lines'][0]} {finding['id']}{match_suffix}")
        print(f"    risk: {finding['risk']}")
        print(f"    mitigation: {finding['mitigation']}")

if mode == "strict" and counts["HIGH"]:
    sys.exit(30)
PY
status=$?
set -e
if [[ "$status" -eq 30 ]]; then
  error "private risk strict mode failed because HIGH findings remain"
fi
exit "$status"
