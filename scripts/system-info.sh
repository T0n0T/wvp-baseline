#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

echo "[system-info] baseline root: $BASE_DIR"
echo "[system-info] runtime template: $RUNTIME_TEMPLATE_DIR"
echo "[system-info] generated runtime: $RUNTIME_DIR"

echo
printf "[system-info] host\n"
run_cmd uname -a

echo
printf "[system-info] git status - baseline\n"
run_in_dir "$BASE_DIR" git status --short || true

echo
printf "[system-info] git status - wvp\n"
run_in_dir "$WVP_DIR" git status --short || true

echo
printf "[system-info] git status - zlm\n"
run_in_dir "$ZLM_DIR" git status --short || true

echo
printf "[system-info] runtime status\n"
run_cmd ls -ld "$RUNTIME_DIR" || true

echo
printf "[system-info] docker compose ps\n"
run_compose ps || true

echo
printf "[system-info] docker images\n"
run_cmd docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
