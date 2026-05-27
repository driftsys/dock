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
# CA bundle tests
# ---------------------------------------------------------------------------

test_deno_cert_env() {
  assert_equals "/etc/ssl/certs/ca-certificates.crt" "$DENO_CERT"
}

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

# ---------------------------------------------------------------------------
# npx shim tests
# ---------------------------------------------------------------------------

test_npx_present() { assert "command -v npx"; }

test_npx_no_args_shows_usage() {
  # npx with no arguments should exit non-zero and print usage
  if npx 2>/dev/null; then
    fail "npx with no args should exit non-zero"
  fi
}

# ---------------------------------------------------------------------------
# npm shim tests
# ---------------------------------------------------------------------------

test_npm_present() { assert "command -v npm"; }

test_npm_no_args_shows_usage() {
  # npm with no arguments should exit non-zero and print usage
  if npm 2>/dev/null; then
    fail "npm with no args should exit non-zero"
  fi
}

test_npm_unsupported_command_errors() {
  if npm publish 2>/dev/null; then
    fail "npm shim should reject unsupported commands"
  fi
}

test_npm_init() {
  local dir
  dir="$(mktemp -d)"
  npm init "$dir"
  assert "[ -f ${dir}/main.ts ] || [ -f ${dir}/deno.json ]" \
    "npm init should scaffold a project"
  rm -rf "$dir"
}
