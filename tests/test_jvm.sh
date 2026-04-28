#!/usr/bin/env bash
# JVM tests — presence + sanity for the :jvm-debian image.
# Sources test_core.sh so all core tests also run.

# shellcheck source=tests/test_core.sh
source "$(dirname "$0")/test_core.sh"

# ---------------------------------------------------------------------------
# Presence tests
# ---------------------------------------------------------------------------

test_java_present()    { assert "command -v java"; }
test_javac_present()   { assert "command -v javac"; }
test_keytool_present() { assert "command -v keytool"; }

# ---------------------------------------------------------------------------
# Sanity tests
# ---------------------------------------------------------------------------

test_java_version() {
  assert "java -version 2>&1 | grep -q 'openjdk version \"17\.'"
}

test_javac_version() {
  assert "javac -version"
}

test_java_home_set() {
  assert "[ -n \"$JAVA_HOME\" ]"
}

test_java_home_valid_dir() {
  assert "[ -d \"$JAVA_HOME\" ]"
}

test_jks_truststore_exists() {
  assert "[ -f \"${JAVA_HOME}/lib/security/cacerts\" ]"
}
