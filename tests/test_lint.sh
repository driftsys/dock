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

test_manifest_has_git_std() {
  assert_manifest_tool '.tools["git-std"]'
  assert_equals "$(git-std --version | awk '{print $2}')" \
    "$(jq -r '.tools["git-std"]' /etc/dock/manifest.json)"
}
test_manifest_has_prim() {
  assert_manifest_tool '.tools.prim'
  assert_equals "$(prim --version | awk '{print $2}')" \
    "$(jq -r '.tools.prim' /etc/dock/manifest.json)"
}

test_manifest_has_shfmt() { assert_manifest_tool '.tools.shfmt'; }

# ---------------------------------------------------------------------------
# Functional tests
# ---------------------------------------------------------------------------

test_prim_non_strict_markdown() {
  local dir
  dir="$(mktemp -d)"
  # Plain Markdown uses the relaxed defaults even without a level-one heading.
  printf 'root = true\n' > "$dir/.editorconfig"
  printf '## Notes\n\nOrdinary repository notes.\n' > "$dir/notes.md"
  assert "prim lint '$dir/notes.md'"
  rm -rf "$dir"
}

test_prim_rejects_and_formats_whitespace() {
  local dir
  dir="$(mktemp -d)"
  printf 'root = true\n' > "$dir/.editorconfig"
  printf 'Repository notes.  \n' > "$dir/notes.txt"
  assert_fails "prim lint '$dir/notes.txt'"
  assert_fails "prim fmt --check '$dir/notes.txt'"
  assert "prim fmt '$dir/notes.txt'"
  printf 'Repository notes.\n' > "$dir/expected.txt"
  assert "cmp -s '$dir/expected.txt' '$dir/notes.txt'"
  assert "prim fmt --check '$dir/notes.txt'"
  assert "prim lint '$dir/notes.txt'"
  rm -rf "$dir"
}

test_git_std_validates_commit_range() {
  local dir base
  dir="$(mktemp -d)"
  git -C "$dir" init -q
  git -C "$dir" config user.name 'Dock tests'
  git -C "$dir" config user.email 'tests@example.com'
  git -C "$dir" -c core.hooksPath=/dev/null commit -q --allow-empty -m 'chore: initialize repository'
  base="$(git -C "$dir" rev-parse HEAD)"
  git -C "$dir" -c core.hooksPath=/dev/null commit -q --allow-empty -m 'fix: validate commit range'
  assert "cd '$dir' && git std lint --range '$base..HEAD'"
  git -C "$dir" -c core.hooksPath=/dev/null commit -q --allow-empty -m 'invalid commit message'
  assert_fails "cd '$dir' && git std lint --range '$base..HEAD'"
  git -C "$dir" -c core.hooksPath=/dev/null commit -q --allow-empty -m 'fix: retain valid tip'
  assert_fails "cd '$dir' && git std lint --range '$base..HEAD'"
  assert "cd '$dir' && git std lint --range 'HEAD^..HEAD'"
  rm -rf "$dir"
}
