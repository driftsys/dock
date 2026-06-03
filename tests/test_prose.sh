#!/usr/bin/env bash
# Prose tests — presence + sanity for the :prose image.
# Sources test_core.sh so all core tests also run.

# shellcheck source=tests/test_core.sh
source "$(dirname "$0")/test_core.sh"

# vale ships only in the Debian variant (it needs glibc + libstdc++); the
# Alpine variant intentionally omits it. Vale-specific tests run on Debian
# and no-op on Alpine.
_prose_has_vale() { [ -f /etc/debian_version ]; }

# ---------------------------------------------------------------------------
# Presence tests
# ---------------------------------------------------------------------------

# vale must be present on Debian and absent on Alpine (it is a gnu-only binary).
# This asserts the contract on BOTH variants rather than silently skipping.
test_vale_present() {
  if _prose_has_vale; then
    assert "command -v vale"
  else
    assert "! command -v vale" "vale must not ship in the Alpine prose variant"
  fi
}
test_typos_present()      { assert "command -v typos"; }
test_harper_cli_present() { assert "command -v harper-cli"; }

# ---------------------------------------------------------------------------
# Version sanity tests
# ---------------------------------------------------------------------------

test_vale_version() {
  _prose_has_vale || return 0
  assert "vale --version"
}

test_typos_version() {
  assert "typos --version"
}

test_harper_cli_version() {
  assert "harper-cli --version"
}

# ---------------------------------------------------------------------------
# Vale style packs pre-installed
# ---------------------------------------------------------------------------

test_vale_styles_path_exists() {
  _prose_has_vale || return 0
  assert "[ -d /usr/local/share/vale/styles ]" \
    "Vale StylesPath directory should exist"
}

test_vale_microsoft_style_installed() {
  _prose_has_vale || return 0
  assert "[ -d /usr/local/share/vale/styles/Microsoft ]" \
    "Microsoft style pack should be installed"
}

test_vale_google_style_installed() {
  _prose_has_vale || return 0
  assert "[ -d /usr/local/share/vale/styles/Google ]" \
    "Google style pack should be installed"
}

test_vale_write_good_style_installed() {
  _prose_has_vale || return 0
  assert "[ -d /usr/local/share/vale/styles/write-good ]" \
    "write-good style pack should be installed"
}

test_vale_proselint_style_installed() {
  _prose_has_vale || return 0
  assert "[ -d /usr/local/share/vale/styles/proselint ]" \
    "proselint style pack should be installed"
}

test_default_vale_config_present() {
  _prose_has_vale || return 0
  assert "[ -f /etc/vale/.vale.ini ]" \
    "Default Vale config should ship at /etc/vale/.vale.ini"
}

# ---------------------------------------------------------------------------
# Functional tests
# ---------------------------------------------------------------------------

test_vale_lints_clean_markdown() {
  _prose_has_vale || return 0
  local dir
  dir="$(mktemp -d)"

  printf 'StylesPath = /usr/local/share/vale/styles\nMinAlertLevel = error\n\n[*.md]\nBasedOnStyles = Vale\n' \
    > "$dir/.vale.ini"
  printf '# Heading\n\nThis is a test paragraph.\n' > "$dir/clean.md"

  vale --config "$dir/.vale.ini" "$dir/clean.md"
  rm -rf "$dir"
}

test_typos_detects_known_typo() {
  local dir
  dir="$(mktemp -d)"

  printf 'This is teh wrong word.\n' > "$dir/typo.md"

  # typos exits non-zero when issues are found. Write to a file and grep it
  # rather than interpolating the captured output into the assert string,
  # which would break if the output ever contained a quote.
  typos "$dir/typo.md" > "$dir/out.txt" 2>&1 || true
  assert "grep -qi teh '$dir/out.txt'" \
    "typos should flag 'teh' as a typo"

  rm -rf "$dir"
}

test_typos_passes_clean_text() {
  local dir
  dir="$(mktemp -d)"

  printf 'This is a perfectly fine sentence.\n' > "$dir/clean.md"
  typos "$dir/clean.md"

  rm -rf "$dir"
}

test_harper_cli_flags_grammar_error() {
  local dir
  dir="$(mktemp -d)"

  # "a apple" is an obvious article error harper should catch. Capture both
  # streams and assert the lint emits a finding, rather than the previous
  # test which swallowed the result and only re-checked `--help` (a no-op
  # already covered by the presence/version tests). We assert on output
  # presence rather than the exit code, which varies across harper versions.
  printf '# Heading\n\nThis is a apple.\n' > "$dir/bad.md"
  harper-cli lint "$dir/bad.md" > "$dir/out.txt" 2>&1 || true
  assert "[ -s '$dir/out.txt' ]" \
    "harper-cli lint should emit a finding for 'a apple'"

  rm -rf "$dir"
}
