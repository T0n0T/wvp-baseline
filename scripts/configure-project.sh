#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

TARGET_IP="${1:-$(detect_host_ip)}"
RUNTIME_ENV="$RUNTIME_DIR/.env"
RUNTIME_MEDIA_CONFIG="$RUNTIME_DIR/media/config.ini"

echo "[configure] target ip: $TARGET_IP"
require_runtime_dir
run_cmd perl -0pi -e "s/^Stream_IP=.*/Stream_IP=$TARGET_IP/m; s/^SDP_IP=.*/SDP_IP=$TARGET_IP/m; s/^SIP_ShowIP=.*/SIP_ShowIP=$TARGET_IP/m" "$RUNTIME_ENV"
run_cmd perl -0pi -e "s/^externIP=.*/externIP=$TARGET_IP/m" "$RUNTIME_MEDIA_CONFIG"

echo "[configure] updated runtime values"
run_cmd grep -nE "^(Stream_IP|SDP_IP|SIP_ShowIP)=" "$RUNTIME_ENV"
run_cmd grep -n "^externIP=" "$RUNTIME_MEDIA_CONFIG"
