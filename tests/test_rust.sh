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
# CA bundle tests
# ---------------------------------------------------------------------------

test_cargo_cainfo_env() {
  assert_equals "/etc/ssl/certs/ca-certificates.crt" "$CARGO_HTTP_CAINFO"
}

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

# ---------------------------------------------------------------------------
# Manifest
# ---------------------------------------------------------------------------

test_manifest_has_rustc() { assert_manifest_tool '.tools.rustc'; }

test_manifest_has_cargo() { assert_manifest_tool '.tools.cargo'; }

test_manifest_has_cargo_audit() { assert_manifest_tool '.tools["cargo-audit"]'; }

test_manifest_has_cargo_deny() { assert_manifest_tool '.tools["cargo-deny"]'; }

test_manifest_has_clippy() { assert_manifest_tool '.tools.clippy'; }

test_manifest_has_rustfmt() { assert_manifest_tool '.tools.rustfmt'; }

# Real diagnostics must survive conversion with their rule and location.
test_clippy_sarif_present() { assert 'command -v clippy-sarif'; }
test_sarif_fmt_present() { assert 'command -v sarif-fmt'; }
test_rust_sarif_manifest() {
  assert_equals '0.8.0' "$(jq -r '.tools["clippy-sarif"]' /etc/dock/manifest.json)"
  assert_equals '0.8.0' "$(jq -r '.tools["sarif-fmt"]' /etc/dock/manifest.json)"
}
test_clippy_sarif_conversion() {
  local dir
  dir="$(mktemp -d)"
  cp -r /fixtures/reporting/rust/. "$dir/"
  assert "cargo clippy --offline --manifest-path '$dir/Cargo.toml' --message-format=json > '$dir/input.json'"
  assert "clippy-sarif < '$dir/input.json' > '$dir/report.sarif'"
  assert "jq -e '.version == \"2.1.0\" and any(.runs[].results[]; .ruleId == \"clippy::redundant_closure\" and .locations[0].physicalLocation.region.startLine == 6 and (.locations[0].physicalLocation.artifactLocation.uri | endswith(\"src/main.rs\")))' '$dir/report.sarif'"
  assert "sarif-fmt < '$dir/report.sarif' > '$dir/formatted.txt'"
  assert "grep -q 'redundant_closure' '$dir/formatted.txt'"
  assert_fails "jq -e . '$dir/formatted.txt'"
  rm -rf "$dir"
}
