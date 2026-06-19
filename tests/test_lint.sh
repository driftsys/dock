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

# ---------------------------------------------------------------------------
# Functional tests
# ---------------------------------------------------------------------------

test_dprint_formats_markdown() {
  local dir
  dir="$(mktemp -d)"

  # A real dprint config must declare a plugin, otherwise dprint errors with
  # "No formatting plugins found" — the failure the previous `|| true` hid.
  # Use the markdown plugin (as the repo's own dprint.json does); dprint
  # downloads the wasm plugin on first use, like the npx/deno tests fetch
  # their deps.
  printf '{\n  "markdown": {},\n  "plugins": ["https://plugins.dprint.dev/markdown-0.17.8.wasm"]\n}\n' \
    > "$dir/dprint.json"

  # Format via --stdin to avoid dprint's working-directory file resolution.
  # First pass formats messy markdown; the second pass must be a no-op
  # (dprint's canonical form is idempotent). This exercises the plugin +
  # formatter end-to-end and fails loudly if dprint is broken, without
  # hard-coding the version-dependent canonical layout.
  printf '#  Heading\n\n\nText.\n' \
    | dprint fmt --stdin doc.md --config "$dir/dprint.json" > "$dir/pass1.md"
  dprint fmt --stdin doc.md --config "$dir/dprint.json" \
    < "$dir/pass1.md" > "$dir/pass2.md"

  assert "test -s '$dir/pass1.md'" \
    "dprint fmt should emit formatted markdown"
  assert "diff '$dir/pass1.md' '$dir/pass2.md'" \
    "dprint fmt output should be idempotent (canonical form)"

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
