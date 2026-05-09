#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

ensure_runtime
ENV_FILE="$RUNTIME_DIR/.env"

read_env_value() {
  local key="$1"
  local line
  line="$(grep -E "^${key}=" "$ENV_FILE" | tail -n 1 || true)"
  printf '%s' "${line#*=}"
}

print_kv() {
  printf '  %-18s %s\n' "$1" "$2"
}

echo "[status] project"
print_kv "baseline" "$BASE_DIR"
print_kv "runtime template" "$RUNTIME_TEMPLATE_DIR"
print_kv "runtime dir" "$RUNTIME_DIR"
print_kv "wvp source" "$WVP_DIR"
print_kv "zlm source" "$ZLM_DIR"

echo
printf '[status] runtime summary\n'
print_kv "WVP url" "http://$(read_env_value Stream_IP):$(read_env_value WebHttp)"
print_kv "WVP admin user" "admin"
print_kv "WVP admin password" "admin"
print_kv "SIP_ShowIP" "$(read_env_value SIP_ShowIP)"
print_kv "SIP_Port" "$(read_env_value SIP_Port)"
print_kv "SIP_Domain" "$(read_env_value SIP_Domain)"
print_kv "SIP_Id" "$(read_env_value SIP_Id)"
print_kv "SIP_Password" "$(read_env_value SIP_Password)"
print_kv "MediaRtmp" "$(read_env_value MediaRtmp)"
print_kv "MediaRtsp" "$(read_env_value MediaRtsp)"
print_kv "MediaRtp" "$(read_env_value MediaRtp)"

echo
printf '[status] host\n'
run_cmd uname -a

echo
printf '[status] git status - baseline\n'
run_in_dir "$BASE_DIR" git status --short || true

echo
printf '[status] git status - wvp\n'
run_in_dir "$WVP_DIR" git status --short || true

echo
printf '[status] git status - zlm\n'
run_in_dir "$ZLM_DIR" git status --short || true

echo
printf '[status] runtime dir\n'
run_cmd ls -ld "$RUNTIME_DIR" || true

echo
printf '[status] docker compose ps\n'
run_in_dir "$RUNTIME_DIR" env \
  WVP_SOURCE_DIR="$WVP_DIR" \
  ZLM_SOURCE_DIR="$ZLM_DIR" \
  BASELINE_ROOT="$BASE_DIR" \
  RUNTIME_DIR="$RUNTIME_DIR" \
  docker compose ps || true

echo
printf '[status] docker images\n'
run_cmd docker images --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}'
