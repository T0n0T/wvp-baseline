#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

echo "[build] sync generated runtime into $RUNTIME_DIR"
ensure_runtime

build_service() {
  local service="$1"
  echo "[build] building $service"
  run_compose build "$service"
}

build_service polaris-media
build_service polaris-wvp
build_service polaris-nginx
