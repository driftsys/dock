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
