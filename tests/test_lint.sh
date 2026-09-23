#!/usr/bin/env bash
# Lint tests — presence + sanity for the :lint image.
# Sources test_core.sh so all core tests also run.

# shellcheck source=tests/test_core.sh
source "$(dirname "$0")/test_core.sh"

# ---------------------------------------------------------------------------
# Presence tests
# ---------------------------------------------------------------------------

test_shellcheck_present()           { assert "command -v shellcheck"; }
test_hadolint_present()             { assert "command -v hadolint"; }
test_gitleaks_present()             { assert "command -v gitleaks"; }
test_shfmt_present()                { assert "command -v shfmt"; }
test_editorconfig_checker_present() { assert "command -v editorconfig-checker"; }
test_git_std_present()              { assert "command -v git-std"; }
test_prim_present()                 { assert "command -v prim"; }
test_deno_absent()                  { assert_fails "command -v deno"; }
test_node_absent()                  { assert_fails "command -v node"; }
test_npm_absent()                   { assert_fails "command -v npm"; }
test_npx_absent()                   { assert_fails "command -v npx"; }
test_dprint_absent()                { assert_fails "command -v dprint"; }

# ---------------------------------------------------------------------------
# Version sanity tests
# ---------------------------------------------------------------------------

test_shellcheck_version() {
  assert "shellcheck --version"
}

test_hadolint_version() {
  assert "hadolint --version"
}

test_gitleaks_version() {
  assert "gitleaks version"
}
test_shfmt_version() {
  assert "shfmt --version"
}

test_editorconfig_checker_version() {
  assert "editorconfig-checker --version"
}

test_git_std_version() {
  assert "git-std --version"
}

test_prim_version() {
  assert "prim --version"
}

# ---------------------------------------------------------------------------
# Manifest
# ---------------------------------------------------------------------------

test_manifest_has_shellcheck() { assert_manifest_tool '.tools.shellcheck'; }

test_manifest_has_hadolint() { assert_manifest_tool '.tools.hadolint'; }
test_manifest_has_gitleaks() { assert_manifest_tool '.tools.gitleaks'; }

test_manifest_has_editorconfig_checker() { assert_manifest_tool '.tools["editorconfig-checker"]'; }

test_manifest_has_git_std() { assert_manifest_tool '.tools["git-std"]'; }
test_manifest_has_prim() { assert_manifest_tool '.tools.prim'; }
