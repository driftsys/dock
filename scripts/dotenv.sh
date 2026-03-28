#!/usr/bin/env bash
# Minimal dotenv CLI: load .env file and exec a command.
# Installed as /usr/local/bin/dotenv in the Debian core image.
#
# Usage:
#   dotenv [-f file] run [--] command [args...]
#
# This covers the common CI pattern where dotenv is used to inject
# .env variables into a subprocess. Mirrors the python-dotenv CLI API
# used by the Alpine dotenv package.

set -euo pipefail

env_file=".env"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -f | --file)
      env_file="$2"
      shift 2
      ;;
    run)
      shift
      [[ "${1:-}" == "--" ]] && shift
      break
      ;;
    --)
      shift
      break
      ;;
    *)
      shift
      ;;
  esac
done

if [[ -f "$env_file" ]]; then
  set -a
  # shellcheck source=/dev/null
  . "$env_file"
  set +a
fi

exec "$@"
