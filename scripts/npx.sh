#!/bin/sh
# scripts/npx.sh — thin shim that delegates npx calls to Deno's npm: specifier.
#
# Usage:
#   npx <package> [args...]
#
# Equivalent to:
#   deno run --allow-all npm:<package> [args...]
#
# Deno fetches the npm package on first use and caches it in DENO_DIR.
set -eu

if [ $# -eq 0 ]; then
  echo "Usage: npx <package> [args...]" >&2
  exit 1
fi

pkg="$1"; shift
exec deno run --allow-all "npm:$pkg" "$@"
