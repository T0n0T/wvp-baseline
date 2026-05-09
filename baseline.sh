#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$ROOT_DIR/scripts"
DRY_RUN=0

usage() {
  cat <<'USAGE'
Usage: ./baseline.sh [--dry-run] <command> [args]

Commands:
  configure [ip]             Update WVP/ZLM IP-related config
  build                      Build required images
  start                      Start the compose stack
  stop                       Stop the compose stack
  status                     Show project runtime status and key config
  help                       Show this help

Options:
  --dry-run                  Print commands only, do not execute
USAGE
}

run_command() {
  local script_name="$1"
  shift
  if [[ "$DRY_RUN" == "1" ]]; then
    exec env BASELINE_DRY_RUN=1 "$SCRIPTS_DIR/$script_name" "$@"
  fi
  exec "$SCRIPTS_DIR/$script_name" "$@"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    help|-h|--help)
      usage
      exit 0
      ;;
    *)
      break
      ;;
  esac
done

COMMAND="${1:-help}"
case "$COMMAND" in
  configure)
    shift
    run_command configure-project.sh "$@"
    ;;
  build)
    shift
    run_command build-images.sh "$@"
    ;;
  start)
    shift
    run_command start-system.sh "$@"
    ;;
  stop)
    shift
    run_command stop-system.sh "$@"
    ;;
  status)
    shift
    run_command system-info.sh "$@"
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    echo "Unknown command: $COMMAND" >&2
    echo >&2
    usage >&2
    exit 1
    ;;
esac
