#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME_TEMPLATE_DIR="$BASE_DIR/runtime"
RUNTIME_DIR="$BASE_DIR/.runtime"
DRY_RUN="${BASELINE_DRY_RUN:-0}"

resolve_repo_dir() {
  local candidate
  for candidate in "$@"; do
    if [[ -e "$candidate" ]]; then
      realpath "$candidate"
      return 0
    fi
  done
  echo "unable to resolve repo path from: $*" >&2
  exit 1
}

WVP_DIR="$(resolve_repo_dir "$BASE_DIR/vendor/wvp-GB28181-pro-src" "$BASE_DIR/vendor/wvp-GB28181-pro" "/home/p9/wvp-GB28181-pro")"
ZLM_DIR="$(resolve_repo_dir "$BASE_DIR/vendor/ZLMediaKit-src" "$BASE_DIR/vendor/ZLMediaKit" "/home/p9/ZLMediaKit")"

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

sync_runtime_file() {
  local rel_path="$1"
  local src="$RUNTIME_TEMPLATE_DIR/$rel_path"
  local dst="$RUNTIME_DIR/$rel_path"
  run_cmd mkdir -p "$(dirname "$dst")"
  run_cmd cp "$src" "$dst"
}

sync_runtime_tree() {
  local rel_path="$1"
  local src="$RUNTIME_TEMPLATE_DIR/$rel_path"
  local dst="$RUNTIME_DIR/$rel_path"
  run_cmd rm -rf "$dst"
  run_cmd mkdir -p "$dst"
  run_cmd cp -a "$src/." "$dst/"
}

ensure_runtime() {
  run_cmd mkdir -p "$RUNTIME_DIR"
  sync_runtime_file ".env"
  sync_runtime_file "docker-compose.yml"
  sync_runtime_tree "media"
  sync_runtime_tree "nginx"
  sync_runtime_tree "redis"
  sync_runtime_tree "wvp"
  run_cmd mkdir -p \
    "$RUNTIME_DIR/logs/media" \
    "$RUNTIME_DIR/logs/nginx" \
    "$RUNTIME_DIR/logs/wvp" \
    "$RUNTIME_DIR/volumes/postgresql/data" \
    "$RUNTIME_DIR/volumes/redis/data" \
    "$RUNTIME_DIR/volumes/video/rtp"
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
