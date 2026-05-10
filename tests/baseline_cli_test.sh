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

echo "[test] baseline dry-run works after command or between command args"
configure_post_command_output="$(cd "$ROOT_DIR" && ./baseline.sh configure --dry-run 10.8.4.63)"
assert_contains "$configure_post_command_output" "[configure]"
assert_contains "$configure_post_command_output" "Stream_IP"
status_post_command_output="$(cd "$ROOT_DIR" && ./baseline.sh status --dry-run)"
assert_contains "$status_post_command_output" "[dry-run]"
assert_contains "$status_post_command_output" "docker compose ps"

echo "[test] baseline configure requires generated runtime and does not touch skeletons"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/repo"
tar -C "$ROOT_DIR" --exclude=.git --exclude=.runtime -cf - . | tar -C "$tmpdir/repo" -xf -
mkdir -p "$tmpdir/repo/vendor/ZLMediaKit"
if (cd "$tmpdir/repo" && ./baseline.sh configure 10.8.4.122 >/tmp/baseline-configure-no-runtime.out 2>/tmp/baseline-configure-no-runtime.err); then
  echo "configure should fail when .runtime does not exist" >&2
  exit 1
fi
configure_missing_runtime_err="$(cat /tmp/baseline-configure-no-runtime.err)"
assert_contains "$configure_missing_runtime_err" ".runtime"

mkdir -p "$tmpdir/repo/.runtime"
cp -a "$tmpdir/repo/skeletons/." "$tmpdir/repo/.runtime/"
configure_real_output="$(cd "$tmpdir/repo" && ./baseline.sh configure 10.8.4.122)"
assert_contains "$configure_real_output" "[configure] updated runtime values"
runtime_env_contents="$(cat "$tmpdir/repo/.runtime/.env")"
assert_contains "$runtime_env_contents" 'Stream_IP=10.8.4.122'
skeleton_env_contents="$(cat "$tmpdir/repo/skeletons/.env")"
assert_contains "$skeleton_env_contents" 'Stream_IP=AUTO_HOST_IP'
env_script_contents="$(cat "$tmpdir/repo/scripts/env.sh")"
assert_contains "$env_script_contents" ': "${BASELINE_HOST_IP:=AUTO_HOST_IP}"'

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
compose_output="$(cd "$ROOT_DIR" && env WVP_SOURCE_DIR="$ROOT_DIR/vendor/wvp-GB28181-pro" ZLM_SOURCE_DIR="$ROOT_DIR/vendor/ZLMediaKit" BASELINE_ROOT="$ROOT_DIR" RUNTIME_DIR="$ROOT_DIR/.runtime-test" docker compose -f skeletons/docker-compose.yml --env-file skeletons/.env config)"
assert_contains "$compose_output" "polaris-media:"
assert_contains "$compose_output" "build:"
if [[ "$compose_output" == *"local/zlmediakit:ppc64le"* ]]; then
  echo "unexpected legacy ppc64le media image reference remains in compose config" >&2
  exit 1
fi

echo "[test] baseline cli regression checks passed"
