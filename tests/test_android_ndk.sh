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
  (cd "$dir" && cargo ndk -t arm64-v8a build)
  assert "find \"$dir\" -name '*.so' | grep -q '.so'"
  rm -rf "$dir"
}

# ---------------------------------------------------------------------------
# Manifest
# ---------------------------------------------------------------------------

test_manifest_has_ndk() { assert_manifest_tool '.tools.ndk'; }

test_manifest_has_cmake() { assert_manifest_tool '.tools.cmake'; }

test_manifest_has_rustc() { assert_manifest_tool '.tools.rustc'; }

test_manifest_has_cargo() { assert_manifest_tool '.tools.cargo'; }

test_manifest_has_cargo_ndk() { assert_manifest_tool '.tools["cargo-ndk"]'; }

test_manifest_has_clippy() { assert_manifest_tool '.tools.clippy'; }

test_manifest_has_rustfmt() { assert_manifest_tool '.tools.rustfmt'; }

# :android-ndk's manifest.sh call does not list build-tools — this proves
# the entry inherited from the parent :android layer survives the merge.
test_manifest_inherits_build_tools() { assert_manifest_tool '.tools["build-tools"]'; }

# java is added two layers up, by :jvm — :android-ndk's manifest.sh call
# does not list it either, so this proves the merge carries tool versions
# through more than one inheritance hop (:jvm -> :android -> :android-ndk).
test_manifest_inherits_java_two_hops() { assert_manifest_tool '.tools.java'; }
