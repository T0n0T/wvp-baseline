#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

assert_contains() {
  local haystack="$1"
  local needle="$2"
  if [[ "$haystack" != *"$needle"* ]]; then
    echo "expected output to contain: $needle" >&2
    exit 1
  fi
}

echo "[test] baseline help exposes simplified commands"
help_output="$(cd "$ROOT_DIR" && ./baseline.sh help)"
assert_contains "$help_output" "configure"
assert_contains "$help_output" "build"
assert_contains "$help_output" "start"
assert_contains "$help_output" "stop"
assert_contains "$help_output" "status"

echo "[test] baseline dry-run configure works"
configure_output="$(cd "$ROOT_DIR" && ./baseline.sh --dry-run configure 10.8.4.63)"
assert_contains "$configure_output" "[configure]"
assert_contains "$configure_output" "Stream_IP"

echo "[test] baseline dry-run build includes media image build"
build_output="$(cd "$ROOT_DIR" && ./baseline.sh --dry-run build)"
assert_contains "$build_output" "docker compose"
assert_contains "$build_output" "polaris-media"
assert_contains "$build_output" "polaris-wvp"
assert_contains "$build_output" "polaris-nginx"

echo "[test] baseline dry-run status prints runtime summary"
status_output="$(cd "$ROOT_DIR" && ./baseline.sh --dry-run status)"
assert_contains "$status_output" "[status] project"
assert_contains "$status_output" "WVP admin"
assert_contains "$status_output" "SIP"
assert_contains "$status_output" "docker compose ps"

echo "[test] baseline compose config uses build for media service"
compose_output="$(cd "$ROOT_DIR" && env WVP_SOURCE_DIR="$ROOT_DIR/vendor/wvp-GB28181-pro" ZLM_SOURCE_DIR="$ROOT_DIR/vendor/ZLMediaKit" BASELINE_ROOT="$ROOT_DIR" RUNTIME_DIR="$ROOT_DIR/.runtime-test" docker compose -f runtime/docker-compose.yml --env-file runtime/.env config)"
assert_contains "$compose_output" "polaris-media:"
assert_contains "$compose_output" "build:"
if [[ "$compose_output" == *"local/zlmediakit:ppc64le"* ]]; then
  echo "unexpected legacy ppc64le media image reference remains in compose config" >&2
  exit 1
fi

echo "[test] baseline cli regression checks passed"
