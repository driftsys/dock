#!/usr/bin/env bash
# Deno tests — presence + sanity for the :deno image.
# Sources test_core.sh so all core tests also run.

# shellcheck source=tests/test_core.sh
source "$(dirname "$0")/test_core.sh"

# ---------------------------------------------------------------------------
# Presence tests
# ---------------------------------------------------------------------------

test_deno_present() { assert "command -v deno"; }

# ---------------------------------------------------------------------------
# Sanity tests
# ---------------------------------------------------------------------------

test_deno_version() {
  assert "deno --version"
}

test_deno_eval() {
  result="$(deno eval 'console.log(1+1)')"
  assert_equals "2" "$result"
}

test_deno_fixture_workflow() {
  local dir
  dir="$(mktemp -d)"
  cp -r /fixtures/deno/. "$dir/"

  deno lint "${dir}/main.ts"
  deno fmt --check "${dir}/main.ts"
  deno test "${dir}/main_test.ts"

  rm -rf "$dir"
}
