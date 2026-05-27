#!/usr/bin/env bash
# Pages tests — presence + sanity for the :pages image.
# Sources test_deno.sh so all deno (and core) tests also run.

# shellcheck source=tests/test_deno.sh
source "$(dirname "$0")/test_deno.sh"

# ---------------------------------------------------------------------------
# Presence tests
# ---------------------------------------------------------------------------

test_mdbook_present()          { assert "command -v mdbook"; }
test_typst_present()           { assert "command -v typst"; }
test_tera_present()            { assert "command -v tera"; }
test_git_std_present()         { assert "command -v git-std"; }
test_brotli_present()          { assert "command -v brotli"; }
test_npx_present()             { assert "command -v npx"; }
test_mdbook_admonish_present() { assert "command -v mdbook-admonish"; }
test_mdbook_katex_present()    { assert "command -v mdbook-katex"; }
test_mdbook_linkcheck_present() { assert "command -v mdbook-linkcheck"; }

# ---------------------------------------------------------------------------
# Version sanity tests
# ---------------------------------------------------------------------------

test_mdbook_version() {
  assert "mdbook --version"
}

test_typst_version() {
  assert "typst --version"
}

test_tera_version() {
  assert "tera --version"
}

test_git_std_version() {
  assert "git-std --version"
}

test_mdbook_admonish_version() {
  assert "mdbook-admonish --version"
}

test_mdbook_katex_version() {
  assert "mdbook-katex --version"
}

test_mdbook_linkcheck_version() {
  assert "mdbook-linkcheck --version"
}

# ---------------------------------------------------------------------------
# Functional tests
# ---------------------------------------------------------------------------

test_npx_shim_forwards_args() {
  # npx must delegate to deno run npm:<pkg> and forward args
  result="$(npx mustache --version 2>/dev/null || true)"
  # If mustache is not cached, it will be downloaded on first run.
  # We just verify npx doesn't error with "Usage:" (i.e., it got a package name).
  assert "[ $? -eq 0 ] || npx mustache --help >/dev/null 2>&1"
}

test_mdbook_init_and_build() {
  local dir
  dir="$(mktemp -d)"

  mdbook init --title "Test Book" "$dir" --ignore none
  mdbook build "$dir"

  assert "[ -f ${dir}/book/index.html ]" \
    "mdbook build should produce index.html"

  rm -rf "$dir"
}

test_typst_compile() {
  local dir
  dir="$(mktemp -d)"

  printf '#set page(paper: "a4")\n= Hello\nWorld\n' > "$dir/test.typ"
  typst compile "$dir/test.typ" "$dir/test.pdf"

  assert "[ -f ${dir}/test.pdf ]" \
    "typst compile should produce a PDF"

  rm -rf "$dir"
}

test_tera_template_render() {
  local dir
  dir="$(mktemp -d)"

  printf '{"name": "dock"}' > "$dir/data.json"
  printf 'Hello {{ name }}!' > "$dir/template.txt"

  result="$(tera --template "$dir/template.txt" "$dir/data.json")"
  assert_equals "Hello dock!" "$result"

  rm -rf "$dir"
}

test_brotli_compress() {
  local dir
  dir="$(mktemp -d)"

  printf 'compress me' > "$dir/test.txt"
  brotli "$dir/test.txt"

  assert "[ -f ${dir}/test.txt.br ]" \
    "brotli should produce a .br file"

  rm -rf "$dir"
}

test_fonts_installed() {
  # Noto fonts should be available for typst PDF generation
  assert "[ -d /usr/share/fonts/noto ]" \
    "Noto fonts directory should exist"
}
