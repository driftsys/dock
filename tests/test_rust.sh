#!/usr/bin/env bash
# Rust tests — presence + sanity for the :rust image.
# Sources test_core.sh so all core tests also run.

# shellcheck source=tests/test_core.sh
source "$(dirname "$0")/test_core.sh"

# ---------------------------------------------------------------------------
# Presence tests
# ---------------------------------------------------------------------------

test_cargo_present()       { assert "command -v cargo"; }
test_clippy_present()      { assert "cargo clippy --version"; }
test_rustfmt_present()     { assert "command -v rustfmt"; }
test_cargo_audit_present() { assert "command -v cargo-audit"; }
test_cargo_deny_present()  { assert "command -v cargo-deny"; }
test_gcc_present()         { assert "command -v gcc"; }
test_pkg_config_present()  { assert "command -v pkg-config"; }

# ---------------------------------------------------------------------------
# Sanity tests
# ---------------------------------------------------------------------------

test_rustc_version() {
  assert "rustc --version"
}

# Run the full cargo workflow in a writable tmp copy of the fixture.
# cargo build generates Cargo.lock which is then used by cargo audit.
test_cargo_fixture_workflow() {
  local dir
  dir="$(mktemp -d)"
  cp -r /fixtures/rust/. "$dir/"

  cargo build   --manifest-path "${dir}/Cargo.toml"
  cargo clippy  --manifest-path "${dir}/Cargo.toml" -- -D warnings
  cargo fmt     --manifest-path "${dir}/Cargo.toml" -- --check
  cargo audit   --file "${dir}/Cargo.lock"
  cargo deny    --manifest-path "${dir}/Cargo.toml" check

  rm -rf "$dir"
}
