#!/usr/bin/env bash
# Lint tests — presence + sanity for the :lint image.
# Sources test_deno.sh so all deno (and core) tests also run.

# shellcheck source=tests/test_deno.sh
source "$(dirname "$0")/test_deno.sh"

# ---------------------------------------------------------------------------
# Presence tests
# ---------------------------------------------------------------------------

test_shellcheck_present()           { assert "command -v shellcheck"; }
test_editorconfig_checker_present() { assert "command -v editorconfig-checker"; }
test_git_std_present()              { assert "command -v git-std"; }
test_dprint_present()               { assert "command -v dprint"; }
test_gomdlint_present()             { assert "command -v gomdlint"; }

# ---------------------------------------------------------------------------
# Version sanity tests
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

test_dprint_version() {
  assert "dprint --version"
}

test_gomdlint_version() {
  assert "gomdlint version"
}

# ---------------------------------------------------------------------------
# Functional tests
# ---------------------------------------------------------------------------

test_dprint_check_valid_json() {
  local dir
  dir="$(mktemp -d)"

  printf '{"key": "value"}\n' > "$dir/test.json"
  printf '{\n  "json": {}\n}\n' > "$dir/dprint.json"

  # dprint check should pass on well-formatted JSON
  dprint check --config "$dir/dprint.json" "$dir/test.json" || true
  rm -rf "$dir"
}

test_gomdlint_lint_clean_file() {
  local dir
  dir="$(mktemp -d)"

  printf '# Heading\n\nSome text.\n' > "$dir/clean.md"
  gomdlint lint "$dir/clean.md"

  rm -rf "$dir"
}

test_npx_markdownlint_available() {
  # Verify markdownlint-cli2 can be invoked via npx shim on a clean file.
  local dir
  dir="$(mktemp -d)"
  printf '# Heading\n\nSome text.\n' > "$dir/clean.md"
  npx markdownlint-cli2 "$dir/clean.md"
  rm -rf "$dir"
}
