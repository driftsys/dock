#!/bin/sh
# scripts/npm.sh — thin shim that delegates npm commands to Deno equivalents.
#
# Supported commands:
#   npm install [args...]     → deno install [args...]
#   npm ci                    → deno install --frozen
#   npm run <script> [args..] → deno task <script> [args...]
#   npm test                  → deno task test
#   npm exec <pkg> [args...]  → deno run --allow-all npm:<pkg> [args...]
#   npm init                  → deno init
#
# Deno reads package.json natively (Deno 2.x+).
set -eu

if [ $# -eq 0 ]; then
  echo "npm: this is a dock shim (delegates to Deno), not full npm." >&2
  echo "Usage: npm <command> [args...]" >&2
  echo "" >&2
  echo "Supported: install, ci, run, test, exec, init" >&2
  exit 1
fi

cmd="$1"; shift

case "$cmd" in
  install|i|add)
    exec deno install "$@"
    ;;
  ci|clean-install)
    exec deno install --frozen "$@"
    ;;
  run|run-script)
    exec deno task "$@"
    ;;
  test|t)
    exec deno task test "$@"
    ;;
  exec)
    if [ $# -eq 0 ]; then
      echo "Usage: npm exec <package> [args...]" >&2
      exit 1
    fi
    pkg="$1"; shift
    exec deno run --allow-all "npm:$pkg" "$@"
    ;;
  init)
    exec deno init "$@"
    ;;
  *)
    echo "npm: unsupported command '$cmd' (this is a dock shim, not full npm)." >&2
    echo "Supported: install, ci, run, test, exec, init" >&2
    exit 1
    ;;
esac
