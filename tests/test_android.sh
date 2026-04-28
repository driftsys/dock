#!/usr/bin/env bash
# Android tests — presence + sanity for the :android-debian image.
# Sources test_jvm.sh so all JVM + core tests also run.

# shellcheck source=tests/test_jvm.sh
source "$(dirname "$0")/test_jvm.sh"

# ---------------------------------------------------------------------------
# Presence tests
# ---------------------------------------------------------------------------

test_sdkmanager_present() { assert "command -v sdkmanager"; }

test_aapt2_present() {
  # aapt2 lives inside build-tools, not on PATH by default.
  assert "find \"$ANDROID_HOME\" -name aapt2 -type f | grep -q aapt2"
}

# ---------------------------------------------------------------------------
# Sanity tests
# ---------------------------------------------------------------------------

test_sdkmanager_list() {
  assert "sdkmanager --list 2>&1 | grep -q 'build-tools'"
}

test_aapt2_version() {
  local aapt2
  aapt2="$(find "$ANDROID_HOME" -name aapt2 -type f | head -1)"
  assert "\"$aapt2\" version"
}

test_android_home_set() {
  assert "[ -n \"$ANDROID_HOME\" ]"
}

test_android_home_valid_dir() {
  assert "[ -d \"$ANDROID_HOME\" ]"
}

test_android_sdk_root_set() {
  assert "[ -n \"$ANDROID_SDK_ROOT\" ]"
}
