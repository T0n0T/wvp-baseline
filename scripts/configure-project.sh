#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

TARGET_IP="${1:-$(detect_host_ip)}"
TEMPLATE_ENV="$RUNTIME_TEMPLATE_DIR/.env"
TEMPLATE_MEDIA_CONFIG="$RUNTIME_TEMPLATE_DIR/media/config.ini"

echo "[configure] target ip: $TARGET_IP"
run_cmd perl -0pi -e "s/^Stream_IP=.*/Stream_IP=$TARGET_IP/m; s/^SDP_IP=.*/SDP_IP=$TARGET_IP/m; s/^SIP_ShowIP=.*/SIP_ShowIP=$TARGET_IP/m" "$TEMPLATE_ENV"
run_cmd perl -0pi -e "s/^externIP=.*/externIP=$TARGET_IP/m" "$TEMPLATE_MEDIA_CONFIG"
ensure_runtime

echo "[configure] updated template values"
run_cmd grep -nE "^(Stream_IP|SDP_IP|SIP_ShowIP)=" "$TEMPLATE_ENV"
run_cmd grep -n "^externIP=" "$TEMPLATE_MEDIA_CONFIG"
