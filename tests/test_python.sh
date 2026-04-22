#!/usr/bin/env bash
# Python tests — presence + sanity for the :python image.
# Sources test_core.sh so all core tests also run.

# shellcheck source=tests/test_core.sh
source "$(dirname "$0")/test_core.sh"

# ---------------------------------------------------------------------------
# Presence tests
# ---------------------------------------------------------------------------

test_python3_present() { assert "command -v python3"; }
test_pip_present()     { assert "command -v pip"; }
test_ruff_present()    { assert "command -v ruff"; }

# ---------------------------------------------------------------------------
# CA bundle tests
# ---------------------------------------------------------------------------

test_pip_cert_env() {
  assert_equals "/etc/ssl/certs/ca-certificates.crt" "$PIP_CERT"
}

# ---------------------------------------------------------------------------
# Sanity tests
# ---------------------------------------------------------------------------

test_python3_version() {
  assert "python3 --version"
}

test_python3_import_json() {
  assert "python3 -c 'import json'"
}

test_ruff_help() {
  assert "ruff check --help"
}
