#!/usr/bin/env bash
# Pages tests — presence + sanity for the :pages image.
# Sources test_core.sh so all core tests also run.

# shellcheck source=tests/test_core.sh
source "$(dirname "$0")/test_core.sh"

# ---------------------------------------------------------------------------
# Presence tests
# ---------------------------------------------------------------------------

test_mdbook_present()          { assert "command -v mdbook"; }
test_typst_present()           { assert "command -v typst"; }
test_tera_present()            { assert "command -v tera"; }
test_brotli_present()          { assert "command -v brotli"; }
test_mdbook_alerts_present()   { assert "command -v mdbook-alerts"; }
test_mdbook_katex_present()    { assert "command -v mdbook-katex"; }
test_lychee_present()          { assert "command -v lychee"; }

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

test_mdbook_alerts_version() {
  assert "mdbook-alerts --version"
}

test_mdbook_katex_version() {
  assert "mdbook-katex --version"
}

test_lychee_version() {
  assert "lychee --version"
}

# ---------------------------------------------------------------------------
# Functional tests
# ---------------------------------------------------------------------------

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
  # Noto fonts should be available for typst PDF generation.
  # Alpine: /usr/share/fonts/noto  Debian: /usr/share/fonts/truetype/noto
  assert "[ -d /usr/share/fonts/noto ] || [ -d /usr/share/fonts/truetype/noto ]" \
    "Noto fonts directory should exist"
}

# lychee detects a broken local link. --offline skips network URLs so the
# test is hermetic; a dangling relative link must make lychee exit non-zero.
test_lychee_detects_broken_link() {
  local dir
  dir="$(mktemp -d)"

  printf '[broken](./missing.md)\n' > "$dir/index.md"
  assert_fails "lychee --offline --no-progress ${dir}/index.md" \
    "lychee should fail on a dangling local link"

  rm -rf "$dir"
}
