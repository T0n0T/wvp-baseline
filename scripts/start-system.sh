#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

echo "[start-system] sync generated runtime into $RUNTIME_DIR"
ensure_runtime

echo "[start-system] starting compose stack from $RUNTIME_DIR"
run_compose up -d
