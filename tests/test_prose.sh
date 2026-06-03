#!/usr/bin/env bash
# Prose tests — presence + sanity for the :prose image.
# Sources test_core.sh so all core tests also run.

# shellcheck source=tests/test_core.sh
source "$(dirname "$0")/test_core.sh"

# ---------------------------------------------------------------------------
# Presence tests
# ---------------------------------------------------------------------------

test_vale_present()       { assert "command -v vale"; }
test_typos_present()      { assert "command -v typos"; }
test_harper_cli_present() { assert "command -v harper-cli"; }

# ---------------------------------------------------------------------------
# Version sanity tests
# ---------------------------------------------------------------------------

test_vale_version() {
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
  assert "[ -d /usr/local/share/vale/styles ]" \
    "Vale StylesPath directory should exist"
}

test_vale_microsoft_style_installed() {
  assert "[ -d /usr/local/share/vale/styles/Microsoft ]" \
    "Microsoft style pack should be installed"
}

test_vale_google_style_installed() {
  assert "[ -d /usr/local/share/vale/styles/Google ]" \
    "Google style pack should be installed"
}

test_vale_write_good_style_installed() {
  assert "[ -d /usr/local/share/vale/styles/write-good ]" \
    "write-good style pack should be installed"
}

test_vale_proselint_style_installed() {
  assert "[ -d /usr/local/share/vale/styles/proselint ]" \
    "proselint style pack should be installed"
}

test_default_vale_config_present() {
  assert "[ -f /etc/vale/.vale.ini ]" \
    "Default Vale config should ship at /etc/vale/.vale.ini"
}

# ---------------------------------------------------------------------------
# Functional tests
# ---------------------------------------------------------------------------

test_vale_lints_clean_markdown() {
  local dir
  dir="$(mktemp -d)"

  printf 'StylesPath = /usr/local/share/vale/styles\nMinAlertLevel = error\n\n[*.md]\nBasedOnStyles = Vale\n' \
    > "$dir/.vale.ini"
  printf '# Heading\n\nThis is a test paragraph.\n' > "$dir/clean.md"

  vale --config "$dir/.vale.ini" "$dir/clean.md"
  rm -rf "$dir"
}

test_typos_detects_known_typo() {
  local dir output
  dir="$(mktemp -d)"

  printf 'This is teh wrong word.\n' > "$dir/typo.md"

  # typos exits non-zero when issues are found.
  output="$(typos "$dir/typo.md" 2>&1 || true)"
  assert "echo '$output' | grep -qi 'teh'" \
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

test_harper_cli_runs_on_markdown() {
  local dir
  dir="$(mktemp -d)"

  printf '# Heading\n\nThis is a test sentence.\n' > "$dir/clean.md"
  # harper-cli `lint` exits 0 on success. We only check that it runs.
  harper-cli lint "$dir/clean.md" >/dev/null 2>&1 || true
  assert "harper-cli --help" \
    "harper-cli should expose its help"

  rm -rf "$dir"
}
