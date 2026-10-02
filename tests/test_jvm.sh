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

test_java17_compiles_and_runs() {
  local status=0
  bash -euo pipefail <<'BASH' || status=$?
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cat > "$work/DockJvmSmoke.java" <<'JAVA'
public class DockJvmSmoke {
    public static void main(String[] args) {
        System.out.println(java.util.HexFormat.of().formatHex(new byte[] {0x17}));
    }
}
JAVA
javac -d "$work" "$work/DockJvmSmoke.java"
test "$(java -cp "$work" DockJvmSmoke)" = 17
BASH
  assert_equals 0 "$status" "the JDK must compile and run Java 17 code"
}

test_java_truststore_imports_corporate_ca() {
  local status=0
  bash -euo pipefail <<'BASH' || status=$?
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cp /fixtures/ca/test-ca.crt "$work/dock-jvm-ca.crt"
dock-bootstrap "$work"
keytool -list -cacerts -storepass changeit > "$work/truststore.txt"
# SHA-256 fingerprint of tests/fixtures/ca/test-ca.crt.
rg -F '0A:B4:9B:C2:79:C9:0A:B9:E9:7B:1E:DC:CC:06:2A:21:DB:C6:D7:29:18:C1:CC:5A:B8:43:B1:20:E5:CD:C0:97' \
  "$work/truststore.txt"
BASH
  assert_equals 0 "$status" "the Java truststore must trust imported corporate CAs"
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

# ---------------------------------------------------------------------------
# Manifest
# ---------------------------------------------------------------------------

test_manifest_has_java() { assert_manifest_tool '.tools.java'; }

test_manifest_records_full_java_version() {
  local java_version manifest_version
  java_version="$(java -version 2>&1 | sed -n 's/^openjdk version "\([^"]*\)".*/\1/p')"
  manifest_version="$(jq -r '.tools.java' /etc/dock/manifest.json)"
  assert_not_equals "" "$java_version"
  assert_equals "$java_version" "$manifest_version"
}
