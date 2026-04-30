#!/usr/bin/env bash
# Android NDK tests — presence + sanity for the :android-ndk-debian image.
# Sources test_android.sh so all Android + JVM + core tests also run.

# shellcheck source=tests/test_android.sh
source "$(dirname "$0")/test_android.sh"

# ---------------------------------------------------------------------------
# Presence tests
# ---------------------------------------------------------------------------

test_ndk_home_set() {
  assert "[ -n \"$ANDROID_NDK_HOME\" ]"
}

test_ndk_home_valid_dir() {
  assert "[ -d \"$ANDROID_NDK_HOME\" ]"
}

test_ndk_clang_present() {
  assert "find \"$ANDROID_NDK_HOME\" -name 'aarch64-linux-android*-clang' -type f | grep -q clang"
}

test_cmake_present() { assert "command -v cmake"; }
test_cargo_present() { assert "command -v cargo"; }
test_rustc_present() { assert "command -v rustc"; }
test_cargo_ndk_present() { assert "command -v cargo-ndk"; }
test_clippy_present() { assert "cargo clippy --version"; }
test_rustfmt_present() { assert "command -v rustfmt"; }

# ---------------------------------------------------------------------------
# Target tests
# ---------------------------------------------------------------------------

test_target_aarch64() {
  assert "rustup target list --installed | grep -q aarch64-linux-android"
}

test_target_armv7() {
  assert "rustup target list --installed | grep -q armv7-linux-androideabi"
}

test_target_x86_64() {
  assert "rustup target list --installed | grep -q x86_64-linux-android"
}

test_target_i686() {
  assert "rustup target list --installed | grep -q i686-linux-android"
}

# ---------------------------------------------------------------------------
# CA bundle tests
# ---------------------------------------------------------------------------

test_cargo_cainfo_env() {
  assert_equals "/etc/ssl/certs/ca-certificates.crt" "$CARGO_HTTP_CAINFO"
}

# ---------------------------------------------------------------------------
# Sanity tests
# ---------------------------------------------------------------------------

test_cmake_version() {
  assert "cmake --version"
}

test_rustc_version() {
  assert "rustc --version"
}

test_cargo_ndk_version() {
  assert "cargo ndk --version"
}

test_cargo_ndk_build_arm64() {
  local dir
  dir="$(mktemp -d)"
  cp -r /fixtures/android-ndk/. "$dir/"
  cargo ndk -t arm64-v8a build --manifest-path "${dir}/Cargo.toml"
  assert "find \"$dir\" -name '*.so' | grep -q '.so'"
  rm -rf "$dir"
}
