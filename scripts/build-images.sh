#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

if [[ ! -d "$RUNTIME_DIR" ]]; then
  echo "[build] initialize runtime from $SKELETONS_DIR into $RUNTIME_DIR"
  materialize_runtime
else
  echo "[build] using existing runtime in $RUNTIME_DIR"
  require_runtime_dir
fi

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
