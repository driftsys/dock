#!/usr/bin/env bash
# Node tests — presence + sanity for the :node image.
# Sources test_core.sh so all core tests also run.

# shellcheck source=tests/test_core.sh
source "$(dirname "$0")/test_core.sh"

# ---------------------------------------------------------------------------
# Presence tests
# ---------------------------------------------------------------------------

test_node_present() { assert "command -v node"; }
test_npm_present()  { assert "command -v npm"; }

# ---------------------------------------------------------------------------
# CA bundle tests
# ---------------------------------------------------------------------------

test_node_extra_ca_certs_env() {
  assert_equals "/etc/ssl/certs/ca-certificates.crt" "$NODE_EXTRA_CA_CERTS"
}

# ---------------------------------------------------------------------------
# Sanity tests
# ---------------------------------------------------------------------------

test_node_version() {
  assert "node --version"
}

test_npm_version() {
  assert "npm --version"
}

test_node_eval() {
  result="$(node -e 'console.log(1+1)')"
  assert_equals "2" "$result"
}
