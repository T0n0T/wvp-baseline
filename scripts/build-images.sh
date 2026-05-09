#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

echo "[build-images] sync generated runtime into $RUNTIME_DIR"
ensure_runtime

echo "[build-images] build WVP and nginx images via runtime compose"
compose_args=(build)
append_build_proxy_args compose_args
compose_args+=(polaris-wvp polaris-nginx)
run_compose "${compose_args[@]}"

echo "[build-images] note: ZLMediaKit image build is currently managed separately"
