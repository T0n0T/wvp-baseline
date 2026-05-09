#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

echo "[build] sync generated runtime into $RUNTIME_DIR"
ensure_runtime

build_service() {
  local service="$1"
  local compose_args=(build)
  append_build_proxy_args compose_args
  compose_args+=("$service")
  echo "[build] building $service"
  run_compose "${compose_args[@]}"
}

build_service polaris-media
build_service polaris-wvp
build_service polaris-nginx
