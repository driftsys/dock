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
#
# Limitation: values are loaded via shell `source`, so an unquoted value
# containing shell metacharacters (space, &, ;, $) aborts the run, and
# command substitution in .env is evaluated. Quote your values. A line-parser
# rewrite that removes these limitations is tracked in driftsys/dock#50.

set -euo pipefail

usage() {
  echo "usage: dotenv [-f file] run [--] command [args...]" >&2
  exit 2
}

env_file=".env"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -f | --file)
      [[ $# -ge 2 ]] || usage
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
      # Anything before `run`/`--` that is not a known flag is malformed.
      # Erroring here prevents `dotenv printenv PATH` (a missing `run`)
      # from silently discarding the command and exiting 0.
      usage
      ;;
  esac
done

# A command is mandatory; never exec an empty argv (which would exit 0
# having run nothing — a silent false success).
[[ $# -gt 0 ]] || usage

if [[ -f "$env_file" ]]; then
  set -a
  # shellcheck source=/dev/null
  . "$env_file"
  set +a
fi

exec "$@"
