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

  # Keep runtime dependency downloads separate from the shipped tool cache.
  local CARGO_HOME="$dir/cargo-home"
  export CARGO_HOME
  assert "cargo build --manifest-path '$dir/Cargo.toml'"
  assert "cargo clippy --manifest-path '$dir/Cargo.toml' -- -D warnings"
  assert "cargo fmt --manifest-path '$dir/Cargo.toml' -- --check"
  assert "cargo audit --file '$dir/Cargo.lock'"
  assert "cargo deny --manifest-path '$dir/Cargo.toml' check"

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

# Missing tools, mismatched LLVM, or empty reports must fail these checks.
test_cargo_nextest_present() { assert 'command -v cargo-nextest'; }
test_cargo_llvm_cov_present() { assert 'command -v cargo-llvm-cov'; }

test_coverage_tool_versions_match_manifest() {
  local tool actual
  for tool in cargo-nextest cargo-llvm-cov; do
    actual="$(cargo "${tool#cargo-}" --version | awk 'NR == 1 {print $2}')"
    assert_not_equals '' "$actual"
    assert_equals "$actual" "$(jq -r --arg tool "$tool" '.tools[$tool]' /etc/dock/manifest.json)"
  done
}

test_llvm_tools_match_active_rust() {
  local host llvm_dir llvm_version
  host="$(rustc -vV | sed -n 's/^host: //p')"
  llvm_dir="$(rustc --print sysroot)/lib/rustlib/$host/bin"
  llvm_version="$(rustc -vV | sed -n 's/^LLVM version: //p')"
  assert "rustup component list --installed | grep -q '^llvm-tools-$host'"
  assert "'$llvm_dir/llvm-cov' --version"
  assert "'$llvm_dir/llvm-profdata' --version"
  assert "'$llvm_dir/llvm-cov' --version | grep -F 'LLVM version $llvm_version'"
  assert "'$llvm_dir/llvm-profdata' --version | grep -F 'LLVM version $llvm_version'"
  assert_equals "$llvm_version" "$(jq -r '.tools["llvm-tools-preview"]' /etc/dock/manifest.json)"
}

test_rust_image_omits_installation_caches() {
  assert_fails "test -d '$CARGO_HOME/registry'"
  assert_fails "test -d '$CARGO_HOME/git'"
  assert_fails "rustup component list --installed | grep -q '^rust-docs-'"
}

check_coverage_fixture_reports() {
  local dir="$1" failures="$2"
  assert "test -s '$dir/reports/junit.xml'"
  assert "yq -p xml -o json '$dir/reports/junit.xml' | jq -e '[.. | objects | select(has(\"testcase\")) | .testcase | if type == \"array\" then .[] else . end] | length == 2'"
  assert "yq -p xml -o json '$dir/reports/junit.xml' | jq -e '.testsuites[\"+@tests\"] == \"2\" and .testsuites[\"+@failures\"] == \"$failures\"'"
  assert "test -s '$dir/reports/cobertura.xml'"
  assert "yq -p xml -o json '$dir/reports/cobertura.xml' | jq -e '(.coverage[\"+@line-rate\"] | tonumber) > 0'"
  assert "test -s '$dir/reports/lcov.info'"
  assert "grep -q '^SF:.*src/lib.rs' '$dir/reports/lcov.info'"
  assert "grep -q '^DA:[0-9][0-9]*,[1-9][0-9]*' '$dir/reports/lcov.info'"
  assert "jq -e '.data[0].totals.lines | (.percent | type) == \"number\" and .percent > 0 and .count > 0 and .covered > 0' '$dir/reports/summary.json'"
}

test_coverage_fixture_success() {
  local dir
  dir="$(mktemp -d)"
  cp -r /fixtures/rust-coverage/. "$dir/"
  assert_status_code 0 "cd '$dir' && bash run.sh"
  check_coverage_fixture_reports "$dir" 0
  rm -rf "$dir"
}

test_coverage_fixture_failure_preserves_reports() {
  local dir
  dir="$(mktemp -d)"
  cp -r /fixtures/rust-coverage/. "$dir/"
  assert_status_code 100 "cd '$dir' && bash run.sh --features intentional-failure"
  check_coverage_fixture_reports "$dir" 1
  assert "yq -p xml -o json '$dir/reports/junit.xml' | jq -e '[.. | objects | select(has(\"failure\"))] | length == 1'"
  rm -rf "$dir"
}
