#!/usr/bin/env bash
# Core tests — presence + sanity for the :core image.
# Sourced by all other test scripts.

# ---------------------------------------------------------------------------
# Presence tests
# ---------------------------------------------------------------------------

test_bash_present()      { assert "command -v bash"; }
test_curl_present()      { assert "command -v curl"; }
test_git_present()       { assert "command -v git"; }
test_git_lfs_present()   { assert "command -v git-lfs"; }
test_gpg_present()       { assert "command -v gpg"; }
test_ssh_present()       { assert "command -v ssh"; }
test_jq_present()        { assert "command -v jq"; }
test_yq_present()        { assert "command -v yq"; }
test_envsubst_present()  { assert "command -v envsubst"; }
test_dotenv_present()    { assert "command -v dotenv"; }
test_patch_present()     { assert "command -v patch"; }
test_find_present()      { assert "command -v find"; }
test_tree_present()      { assert "command -v tree"; }
test_zip_present()       { assert "command -v zip"; }
test_unzip_present()     { assert "command -v unzip"; }
test_diff_present()      { assert "command -v diff"; }

# ---------------------------------------------------------------------------
# Sanity tests
# ---------------------------------------------------------------------------

test_git_version() {
  assert "git --version"
}

test_git_lfs_version() {
  assert "git-lfs version"
}

test_jq_parses_json() {
  result="$(echo '{"key":"value"}' | jq -r '.key')"
  assert_equals "value" "$result"
}

test_yq_parses_yaml() {
  result="$(printf 'key: value\n' | yq '.key')"
  assert_equals "value" "$result"
}

test_yq_parses_json() {
  result="$(echo '{"key":"value"}' | yq -p json '.key')"
  assert_equals "value" "$result"
}

test_envsubst_works() {
  local template="hello \$FOO"
  result="$(FOO=bar envsubst <<< "$template")"
  assert_equals "hello bar" "$result"
}

# dotenv shim loads a .env file and execs the wrapped command with it applied.
test_dotenv_loads_env() {
  local env_file
  env_file="$(mktemp)"
  printf 'DOCK_TEST_KEY=loaded\n' > "$env_file"
  result="$(dotenv -f "$env_file" run -- printenv DOCK_TEST_KEY)"
  rm -f "$env_file"
  assert_equals "loaded" "$result"
}

test_timezone_data() {
  assert "[ -f /usr/share/zoneinfo/UTC ]"
}

test_manifest_exists() {
  assert "[ -f /etc/dock/manifest.json ]"
}

test_manifest_valid_json() {
  assert "jq empty /etc/dock/manifest.json"
}

test_manifest_has_image() {
  result="$(jq -r '.image' /etc/dock/manifest.json)"
  assert_not_equals "" "$result"
}

assert_manifest_tool() {
  local jq_path="$1"
  local result
  result="$(jq -r "$jq_path" /etc/dock/manifest.json)"
  # Requires an actual dotted-or-bare version number, not just "present" —
  # a resolver that recorded its own command string instead of a real
  # version (e.g. "rustc --version") would fail this, where a bare
  # non-null/non-n/a check would not.
  assert "[[ \"$result\" =~ ^[0-9]+(\.[0-9]+)*\$ ]]"
}

# The fixed baseline manifest.sh seeds on :core/:core-debian, before any
# per-image tools are merged in. Every descendant image inherits these —
# if any were ever silently dropped from the baseline, this is the only
# place it would be caught, since no descendant test checks them.
test_manifest_has_git() { assert_manifest_tool '.tools.git'; }

test_manifest_has_git_lfs() { assert_manifest_tool '.tools["git-lfs"]'; }

test_manifest_has_bash() { assert_manifest_tool '.tools.bash'; }

test_manifest_has_curl() { assert_manifest_tool '.tools.curl'; }

test_manifest_has_jq() { assert_manifest_tool '.tools.jq'; }

test_manifest_has_yq() { assert_manifest_tool '.tools.yq'; }

test_manifest_has_gpg() { assert_manifest_tool '.tools.gpg'; }

test_manifest_has_ssh() { assert_manifest_tool '.tools.ssh'; }

# ---------------------------------------------------------------------------
# Corporate CA support
# ---------------------------------------------------------------------------

test_dock_bootstrap_present() {
  assert "command -v dock-bootstrap"
}

test_ca_drop_dir_exists() {
  assert "[ -d /etc/dock/ca.d ]"
}

test_ssl_cert_file_env() {
  assert_equals "/etc/ssl/certs/ca-certificates.crt" "$SSL_CERT_FILE"
}

test_ssl_cert_dir_env() {
  assert_equals "/etc/ssl/certs" "$SSL_CERT_DIR"
}

test_curl_ca_bundle_env() {
  assert_equals "/etc/ssl/certs/ca-certificates.crt" "$CURL_CA_BUNDLE"
}

test_git_ssl_cainfo_env() {
  assert_equals "/etc/ssl/certs/ca-certificates.crt" "$GIT_SSL_CAINFO"
}

# dock-bootstrap exits 0 with no certs present (empty ca.d, no PEM env vars)
test_dock_bootstrap_noop() {
  assert "dock-bootstrap /etc/dock/ca.d"
}

# dock-bootstrap imports a certificate file from the drop directory.
# Uses a pre-generated test fixture cert to avoid requiring openssl.
test_dock_bootstrap_imports_file() {
  local ca_dir
  ca_dir="$(mktemp -d)"

  cp /fixtures/ca/test-ca.crt "$ca_dir/"

  dock-bootstrap "$ca_dir"

  assert "[ -f /usr/local/share/ca-certificates/test-ca.crt ]" \
    "test cert should be copied to ca-certificates directory"

  rm -rf "$ca_dir"
}

# dock-bootstrap detects PEM certificates in environment variables.
test_dock_bootstrap_imports_env_var() {
  local cert_pem
  cert_pem="$(cat /fixtures/ca/test-ca.crt)"

  # Export a PEM cert as an env var, run dock-bootstrap, check dest dir
  DOCK_TEST_CA="$cert_pem" \
    dock-bootstrap /nonexistent 2>/dev/null

  # shellcheck disable=SC2012
  assert "ls /usr/local/share/ca-certificates/env-DOCK_TEST_CA-*.crt >/dev/null 2>&1" \
    "PEM cert from env var should be written to ca-certificates directory"
}

# dock-bootstrap respects DOCK_SKIP_CA
test_dock_bootstrap_skip() {
  local output
  output="$(DOCK_SKIP_CA=1 dock-bootstrap 2>&1)"
  assert_equals "dock-bootstrap: DOCK_SKIP_CA=1, skipping" "$output"
}
