#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKELETONS_DIR="$BASE_DIR/skeletons"
RUNTIME_DIR="$BASE_DIR/.runtime"
DRY_RUN="${BASELINE_DRY_RUN:-0}"
ENV_SCRIPT="$BASE_DIR/scripts/env.sh"
source "$ENV_SCRIPT"

require_repo_dir() {
  local dir="$1"
  local name="$2"
  if [[ ! -e "$dir" ]]; then
    echo "$name source directory is missing: $dir" >&2
    exit 1
  fi
  realpath "$dir"
}

WVP_DIR="$(require_repo_dir "$BASE_DIR/vendor/wvp-GB28181-pro" "WVP")"
ZLM_DIR="$(require_repo_dir "$BASE_DIR/vendor/ZLMediaKit" "ZLMediaKit")"

require_runtime_dir() {
  if [[ ! -d "$RUNTIME_DIR" ]]; then
    echo "generated runtime directory is missing: $RUNTIME_DIR" >&2
    echo "run ./baseline.sh start, build, or status first to initialize it from skeletons/" >&2
    exit 1
  fi
}

quote_args() {
  printf '%q ' "$@"
}

run_cmd() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '[dry-run] '
    quote_args "$@"
    printf '\n'
    return 0
  fi
  "$@"
}

run_in_dir() {
  local dir="$1"
  shift
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '[dry-run] (cd %q && ' "$dir"
    quote_args "$@"
    printf ')\n'
    return 0
  fi
  (cd "$dir" && "$@")
}

detect_host_ip() {
  if python3 - 2>/dev/null <<'PY'
import socket

s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
try:
    s.connect(("1.1.1.1", 80))
    print(s.getsockname()[0])
finally:
    s.close()
PY
  then
    return 0
  fi

  if [[ -n "$BASELINE_HOST_IP" && "$BASELINE_HOST_IP" != "AUTO_HOST_IP" ]]; then
    printf '%s\n' "$BASELINE_HOST_IP"
    return 0
  fi

  printf '%s\n' "127.0.0.1"
}

sync_runtime_file() {
  local rel_path="$1"
  local src="$SKELETONS_DIR/$rel_path"
  local dst="$RUNTIME_DIR/$rel_path"
  run_cmd mkdir -p "$(dirname "$dst")"
  run_cmd cp "$src" "$dst"
}

sync_runtime_tree() {
  local rel_path="$1"
  local src="$SKELETONS_DIR/$rel_path"
  local dst="$RUNTIME_DIR/$rel_path"
  run_cmd rm -rf "$dst"
  run_cmd mkdir -p "$dst"
  run_cmd cp -a "$src/." "$dst/"
}

materialize_runtime_network_config() {
  local target_ip="$1"
  local env_file="$RUNTIME_DIR/.env"
  local media_config="$RUNTIME_DIR/media/config.ini"
  run_cmd perl -0pi -e "s/^Stream_IP=.*/Stream_IP=$target_ip/m; s/^SDP_IP=.*/SDP_IP=$target_ip/m; s/^SIP_ShowIP=.*/SIP_ShowIP=$target_ip/m; s/^WebHttp=.*/WebHttp=$BASELINE_WEB_HTTP/m; s/^WebHttps=.*/WebHttps=$BASELINE_WEB_HTTPS/m; s/^MediaRtmp=.*/MediaRtmp=$BASELINE_MEDIA_RTMP/m; s/^MediaRtsp=.*/MediaRtsp=$BASELINE_MEDIA_RTSP/m; s/^MediaRtp=.*/MediaRtp=$BASELINE_MEDIA_RTP/m; s/^MediaRtc=.*/MediaRtc=$BASELINE_MEDIA_RTC/m; s/^SIP_Port=.*/SIP_Port=$BASELINE_SIP_PORT/m; s/^SIP_Domain=.*/SIP_Domain=$BASELINE_SIP_DOMAIN/m; s/^SIP_Id=.*/SIP_Id=$BASELINE_SIP_ID/m; s/^SIP_Password=.*/SIP_Password=$BASELINE_SIP_PASSWORD/m; s/^RecordSip=.*/RecordSip=$BASELINE_RECORD_SIP/m; s/^RecordPushLive=.*/RecordPushLive=$BASELINE_RECORD_PUSH_LIVE/m" "$env_file"
  run_cmd perl -0pi -e "s/^externIP=.*/externIP=$target_ip/m" "$media_config"
}

materialize_runtime() {
  local host_ip
  host_ip="$(detect_host_ip)"
  run_cmd mkdir -p "$RUNTIME_DIR"
  sync_runtime_file ".env"
  sync_runtime_file "docker-compose.yml"
  if [[ "${BASELINE_SECCOMP_UNCONFINED:-false}" == "true" ]]; then
    sync_runtime_file "docker-compose.override.yml"
  fi
  sync_runtime_tree "media"
  sync_runtime_tree "nginx"
  sync_runtime_tree "redis"
  sync_runtime_tree "wvp"
  materialize_runtime_network_config "$host_ip"
  run_cmd mkdir -p \
    "$RUNTIME_DIR/logs/media" \
    "$RUNTIME_DIR/logs/nginx" \
    "$RUNTIME_DIR/logs/wvp" \
    "$RUNTIME_DIR/volumes/postgresql/data" \
    "$RUNTIME_DIR/volumes/redis/data" \
    "$RUNTIME_DIR/volumes/video/rtp"
}

ensure_runtime() {
  if [[ ! -d "$RUNTIME_DIR" ]]; then
    materialize_runtime
    return 0
  fi
  require_runtime_dir
}

append_build_proxy_args() {
  local -n target_ref=$1
  local name value
  for name in http_proxy https_proxy no_proxy HTTP_PROXY HTTPS_PROXY NO_PROXY; do
    value="${!name-}"
    if [[ -n "$value" ]]; then
      target_ref+=(--build-arg "$name=$value")
    fi
  done
}

run_compose() {
  ensure_runtime
  run_in_dir "$RUNTIME_DIR" env \
    WVP_SOURCE_DIR="$WVP_DIR" \
    ZLM_SOURCE_DIR="$ZLM_DIR" \
    BASELINE_ROOT="$BASE_DIR" \
    RUNTIME_DIR="$RUNTIME_DIR" \
    docker compose "$@"
}
