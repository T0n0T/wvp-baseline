#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

echo "[stop] stopping compose stack from $RUNTIME_DIR"
run_compose down
