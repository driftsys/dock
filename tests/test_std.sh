#!/usr/bin/env bash
# Std tests — presence + sanity for the :std image.
# Sources test_core.sh so all core tests also run.

# shellcheck source=tests/test_core.sh
source "$(dirname "$0")/test_core.sh"

# ---------------------------------------------------------------------------
# Presence tests
# ---------------------------------------------------------------------------

test_git_std_present() { assert "command -v git-std"; }

# ---------------------------------------------------------------------------
# Version sanity tests
# ---------------------------------------------------------------------------

test_git_std_version() {
  assert "git-std --version"
}

# ---------------------------------------------------------------------------
# Functional tests
# ---------------------------------------------------------------------------

test_git_std_subcommand() {
  # git-std is invoked as `git std` via git subcommand discovery.
  assert "git std --version"
}
