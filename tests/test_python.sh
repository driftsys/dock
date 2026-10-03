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

# ---------------------------------------------------------------------------
# Manifest
# ---------------------------------------------------------------------------

test_manifest_has_python3() { assert_manifest_tool '.tools.python3'; }

test_manifest_has_pip3() { assert_manifest_tool '.tools["pip3"]'; }

test_manifest_has_ruff() { assert_manifest_tool '.tools.ruff'; }

# uv isolates script dependencies while retaining the image's interpreter.
test_uv_present() { assert 'command -v uv'; }
test_uvx_present() { assert 'command -v uvx'; }
test_pip3_present() { assert 'command -v pip3'; }
test_uv_manifest() {
  assert_equals "$(uv --version | awk '{print $2}')" "$(jq -r '.tools.uv' /etc/dock/manifest.json)"
  assert_equals "$(ruff --version | awk '{print $2}')" "$(jq -r '.tools.ruff' /etc/dock/manifest.json)"
}
test_uv_defaults() {
  assert_equals never "${UV_PYTHON_DOWNLOADS:-}"
  assert_equals copy "${UV_LINK_MODE:-}"
  assert_equals true "${UV_SYSTEM_CERTS:-}"
}
test_uv_offline_inline_script() {
  local dir
  dir="$(mktemp -d)"
  assert "python3 /fixtures/python/make_wheel.py '$dir/wheels'"
  assert "UV_CACHE_DIR='$dir/cache' uv run --offline --no-index --find-links '$dir/wheels' /fixtures/python/inline.py > '$dir/result.json'"
  assert "jq -e '.message == \"offline dependency works\" and .python == \"/usr\"' '$dir/result.json'"
  assert "[ ! -d '$dir/cache/python' ]"
  rm -rf "$dir"
}
test_ruff_sarif() {
  local report
  report="$(mktemp)"
  assert_status_code 1 "ruff check --no-cache --isolated --output-format sarif /fixtures/python/ruff.py > '$report'"
  assert "jq -e '.version == \"2.1.0\" and any(.runs[].results[]; .ruleId == \"F401\" and .locations[0].physicalLocation.region.startLine == 1)' '$report'"
  rm -f "$report"
}

# Actual HTTPS installation proves verification is enabled and imported CAs work.
# tests/run.sh runs this test again with /etc/ssl/certs mounted read-only.
test_uv_corporate_ca() {
  local dir pid port output status=0 wheel
  dir="$(mktemp -d)"
  python3 /fixtures/python/make_wheel.py "$dir/wheels"
  python3 /fixtures/python/https_server.py "$dir/wheels" > "$dir/server.log" 2>&1 &
  pid=$!
  for _ in $(seq 1 100); do
    if [ -s "$dir/server.log" ]; then break; fi
    sleep 0.05
  done
  port="$(head -n1 "$dir/server.log")"
  if ! [[ "$port" =~ ^[0-9]+$ ]]; then
    kill "$pid" 2>/dev/null || true
    fail 'TLS fixture did not start'
    return
  fi
  wheel="https://localhost:$port/dock_fixture-1.0.0-py3-none-any.whl"
  assert "uv venv --python /usr/bin/python3 '$dir/venv'"
  # Core tests may already have imported this CA; override trust for this probe.
  output="$(SSL_CERT_FILE=/usr/share/ca-certificates/mozilla/ISRG_Root_X1.crt     SSL_CERT_DIR='' UV_CACHE_DIR="$dir/untrusted-cache" UV_HTTP_RETRIES=0     uv pip install --python "$dir/venv/bin/python" --no-deps "$wheel" 2>&1)" || status=$?
  assert_not_equals 0 "$status" 'Untrusted endpoint must fail TLS verification'
  assert_matches 'certificate|Certificate|UnknownIssuer' "$output"
  mkdir "$dir/ca"
  cp /fixtures/tls/ca.crt "$dir/ca/uv-fixture.crt"
  assert "dock-bootstrap '$dir/ca'"
  # Keep trust changes local to this test's subshell.
  assert "if [ -f /etc/dock/ca.env ]; then . /etc/dock/ca.env; fi; UV_CACHE_DIR='$dir/trusted-cache' uv pip install --python '$dir/venv/bin/python' --no-deps '$wheel'"
  assert_equals 'offline dependency works' "$("$dir/venv/bin/python" -c 'from dock_fixture import MESSAGE; print(MESSAGE)')"
  if [ "${DOCK_TEST_READONLY_CA:-0}" = 1 ]; then
    assert "grep -q 'SSL_CERT_FILE=/etc/dock/ca-bundle.crt' /etc/dock/ca.env"
  fi
  kill "$pid"
  wait "$pid" 2>/dev/null || true
  rm -rf "$dir"
}
