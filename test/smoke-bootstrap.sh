#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$ROOT_DIR/bootstrap.sh" --dry-run --tier minimal
"$ROOT_DIR/bootstrap.sh" --dry-run --tier cli
"$ROOT_DIR/scripts/verify-no-secrets.sh"
