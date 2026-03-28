#!/usr/bin/env bash
# Lint tests — presence + sanity for the :lint image.
# Sources test_core.sh so all core tests also run.

# shellcheck source=tests/test_core.sh
source "$(dirname "$0")/test_core.sh"

# ---------------------------------------------------------------------------
# Presence tests
# ---------------------------------------------------------------------------

test_shellcheck_present()           { assert "command -v shellcheck"; }
test_editorconfig_checker_present() { assert "command -v editorconfig-checker"; }
test_git_std_present()              { assert "command -v git-std"; }

# ---------------------------------------------------------------------------
# Sanity tests
# ---------------------------------------------------------------------------

test_shellcheck_version() {
  assert "shellcheck --version"
}

test_editorconfig_checker_version() {
  assert "editorconfig-checker --version"
}

test_git_std_version() {
  assert "git-std --version"
}
