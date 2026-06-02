#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/log.sh
. "$ROOT_DIR/scripts/lib/log.sh"

mode="report"
case "${1:-}" in
  --report|"") mode="report" ;;
  --strict) mode="strict" ;;
  --help|-h)
    cat <<'USAGE'
Usage: scripts/audit-public-readiness.sh [--report|--strict]

Checks whether the repo is safe to publish publicly without printing secret values.

--report  Fail on high-confidence secrets only; privacy findings are warnings.
--strict  Fail on high-confidence secrets and privacy/public-surface findings.
USAGE
    exit 0
    ;;
  *) die "unknown option: $1" ;;
esac

cd "$ROOT_DIR"

set +e
python3 - "$mode" <<'PY'
import pathlib
import re
import subprocess
import sys
from collections import defaultdict

mode = sys.argv[1]
root = pathlib.Path.cwd()

secret_patterns = [
    ("private-key-header", re.compile(rb"BEGIN [A-Z0-9 ]*PRIVATE KEY")),
    ("github-token", re.compile(rb"(gh[pousr]|github_pat)_[A-Za-z0-9_]{20,}")),
    ("aws-access-key-id", re.compile(rb"AKIA[0-9A-Z]{16}")),
    ("api-key-token", re.compile(rb"sk-(proj-|ant-)?[A-Za-z0-9_-]{20,}")),
    ("google-api-key", re.compile(rb"AIza[0-9A-Za-z_-]{35}")),
    ("slack-token", re.compile(rb"xox[baprs]-[0-9A-Za-z-]{20,}")),
    ("oauth-token-json", re.compile(rb'"oauth[_-]?token"\s*:\s*"[^"]{12,}"')),
    ("credential-json-field", re.compile(rb'"(access_token|refresh_token|client_secret|private_key)"\s*:\s*"[^"]{16,}"')),
]

sensitive_filename = re.compile(
    r"(^|/)(id_rsa|id_ed25519|id_ecdsa|known_hosts|\.env(\..*)?|.*\.(pem|p12|pfx|key)|credentials\.json|token\.json|tokens\.json|keys\.json|client_secret\.json|service-account\.json)$"
)

privacy_patterns = [
    ("email-address", re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")),
    ("absolute-home-path", re.compile(r"/Users/[A-Za-z0-9._-]+\b")),
    ("personal-username", re.compile(r"\balansynn\b", re.I)),
    ("institution-gatech", re.compile(r"\bgatech\b|georgia tech", re.I)),
    ("institution-nersc", re.compile(r"\bnersc\b", re.I)),
    ("cloud-account-context", re.compile(r"\baws\b|amazonaws\.com", re.I)),
    ("password-manager-reference", re.compile(r"op://|onepassword|1Password", re.I)),
    ("ssh-config-directive", re.compile(r"^\s*(Host|HostName|User|IdentityFile|IdentityAgent|Include)\s+", re.M)),
]


def git_lines(args, *, binary=False):
    return subprocess.check_output(["git", *args], text=not binary)


def tracked_files():
    raw = subprocess.check_output(["git", "ls-files", "-z"])
    return [p.decode("utf-8", "replace") for p in raw.split(b"\0") if p]


def is_text(data):
    return b"\0" not in data[:4096]


def scan_bytes(data, rel, patterns):
    results = []
    if not is_text(data):
        return results
    for reason, pat in patterns:
        for match in pat.finditer(data):
            line = data[: match.start()].count(b"\n") + 1
            results.append({"file": rel, "line": line, "reason": reason})
    return results

current_secret_findings = []
privacy_skip_paths = {
    "scripts/audit-public-readiness.sh",
    "scripts/lib/secrets.sh",
    "docs/public-repo-readiness.md",
    "docs/secrets-policy.md",
    "docs/verification-readiness.md",
}

privacy_findings = []
for rel in tracked_files():
    path = root / rel
    if sensitive_filename.search(rel):
        current_secret_findings.append({"file": rel, "line": None, "reason": "sensitive-filename"})
    try:
        data = path.read_bytes()
    except OSError:
        continue
    current_secret_findings.extend(scan_bytes(data, rel, secret_patterns))
    if rel not in privacy_skip_paths and is_text(data):
        text = data.decode("utf-8", "ignore")
        for reason, pat in privacy_patterns:
            for match in pat.finditer(text):
                line = text[: match.start()].count("\n") + 1
                privacy_findings.append({"file": rel, "line": line, "reason": reason})

history_secret_findings = []
seen_history = set()
commits = git_lines(["rev-list", "--all"]).splitlines()
for commit in commits:
    raw_files = subprocess.check_output(["git", "ls-tree", "-r", "-z", "--name-only", commit])
    for fb in raw_files.split(b"\0"):
        if not fb:
            continue
        rel = fb.decode("utf-8", "replace")
        if sensitive_filename.search(rel):
            key = (rel, "sensitive-filename")
            if key not in seen_history:
                seen_history.add(key)
                history_secret_findings.append({"file": rel, "reason": "sensitive-filename", "commit": commit[:12]})
        try:
            data = subprocess.check_output(["git", "show", f"{commit}:{rel}"], stderr=subprocess.DEVNULL, timeout=5)
        except Exception:
            continue
        for finding in scan_bytes(data, rel, secret_patterns):
            key = (finding["file"], finding["reason"])
            if key not in seen_history:
                seen_history.add(key)
                history_secret_findings.append({"file": finding["file"], "reason": finding["reason"], "commit": commit[:12]})

privacy_by_file = defaultdict(lambda: defaultdict(list))
for finding in privacy_findings:
    privacy_by_file[finding["file"]][finding["reason"]].append(finding["line"])

print(f"[INFO] scanned {len(tracked_files())} tracked files and {len(commits)} commits")
if current_secret_findings:
    print("[ERROR] high-confidence secret findings in current tree:")
    for f in current_secret_findings:
        loc = f["file"] if f["line"] is None else f'{f["file"]}:{f["line"]}'
        print(f"  - {loc} ({f['reason']})")
else:
    print("[OK] current tree high-confidence secret scan passed")

if history_secret_findings:
    print("[ERROR] high-confidence secret findings in git history:")
    for f in history_secret_findings:
        print(f"  - {f['file']} ({f['reason']}, first-seen commit {f['commit']})")
else:
    print("[OK] git history high-confidence secret scan passed")

if privacy_by_file:
    print("[WARN] public privacy review findings (not necessarily credentials):")
    for rel in sorted(privacy_by_file):
        parts = []
        for reason in sorted(privacy_by_file[rel]):
            lines = privacy_by_file[rel][reason]
            preview = ",".join(str(x) for x in lines[:8])
            if len(lines) > 8:
                preview += ",..."
            parts.append(f"{reason}@{preview}")
        print(f"  - {rel}: {'; '.join(parts)}")
else:
    print("[OK] no public privacy review findings")

if current_secret_findings or history_secret_findings:
    sys.exit(2)
if mode == "strict" and privacy_by_file:
    sys.exit(20)
PY
status=$?
set -e
if [[ "$status" -eq 20 ]]; then
  error "public readiness strict mode failed because privacy findings require review/sanitization"
fi
exit "$status"
