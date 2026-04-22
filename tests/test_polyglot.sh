#!/usr/bin/env bash
# Polyglot tests — presence + sanity for the :polyglot image.
# Sources test_rust.sh (which sources test_core.sh) so all upstream tests
# also run, plus polyglot-specific interop tests.

# shellcheck source=tests/test_rust.sh
source "$(dirname "$0")/test_rust.sh"

# ---------------------------------------------------------------------------
# Deno presence (re-declared here for polyglot)
# ---------------------------------------------------------------------------

test_polyglot_deno_present() { assert "command -v deno"; }

# ---------------------------------------------------------------------------
# Python presence (re-declared here for polyglot)
# ---------------------------------------------------------------------------

test_polyglot_python3_present() { assert "command -v python3"; }
test_polyglot_ruff_present()    { assert "command -v ruff"; }

# ---------------------------------------------------------------------------
# CA bundle tests (Deno + pip; Cargo inherited from test_rust.sh)
# ---------------------------------------------------------------------------

test_polyglot_deno_cert_env() {
  assert_equals "/etc/ssl/certs/ca-certificates.crt" "$DENO_CERT"
}

test_polyglot_pip_cert_env() {
  assert_equals "/etc/ssl/certs/ca-certificates.crt" "$PIP_CERT"
}

# ---------------------------------------------------------------------------
# Interop: Deno FFI loads a Rust-compiled shared library
# ---------------------------------------------------------------------------

test_deno_ffi_loads_rust_library() {
  local dir
  dir="$(mktemp -d)"
  cp -r /fixtures/ffi/. "$dir/"

  # Compile the Rust FFI library; output goes to writable tmp dir
  cargo build \
    --manifest-path "${dir}/lib/Cargo.toml" \
    --release \
    --target-dir "${dir}/target"

  # Run the Deno FFI loader pointing at the compiled .so
  deno run --allow-ffi --unstable-ffi \
    "${dir}/main.ts" "${dir}/target/release/libffi_add.so"

  rm -rf "$dir"
}
