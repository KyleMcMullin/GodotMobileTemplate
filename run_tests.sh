#!/usr/bin/env bash
# Template checks always run; an installed gdUnit4 suite runs afterwards.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$REPO_ROOT/scripts/run_tests.py" "$@"
