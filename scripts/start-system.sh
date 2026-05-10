#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

if [[ ! -d "$RUNTIME_DIR" ]]; then
  echo "[start] initialize runtime from $SKELETONS_DIR into $RUNTIME_DIR"
  materialize_runtime
else
  echo "[start] using existing runtime in $RUNTIME_DIR"
  require_runtime_dir
fi

echo "[start] starting compose stack from $RUNTIME_DIR"
run_compose up -d
