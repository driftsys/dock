#!/usr/bin/env bash
# Host tests for Android release tag inputs. Requires mikefarah/yq v4.

setup_suite() {
    REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    WORKFLOW="${REPO_DIR}/.github/workflows/release.yml"
}

setup() {
    TEST_DIR="$(mktemp -d)"
    export GITHUB_OUTPUT="${TEST_DIR}/outputs"
    cp "${REPO_DIR}/docker-bake.hcl" "${TEST_DIR}/docker-bake.hcl"
}

teardown() {
    rm -rf "$TEST_DIR"
}

run_resolve_step() {
    local step="$1" body
    body="$(STEP_NAME="$step" yq -r \
        '.jobs.merge.steps[] | select(.name == strenv(STEP_NAME)) | .run' \
        "$WORKFLOW")"
    (cd "$TEST_DIR" && bash -e -o pipefail -c "$body")
}

test_release_resolves_decimal_android_api() {
    assert_status_code 0 'run_resolve_step "Resolve Android API level"'
    assert_equals 'api=37.2' "$(cat "$GITHUB_OUTPUT")" \
        "Release tag input must preserve the Android API minor version"
}

test_release_resolves_integer_android_api() {
    cat > "${TEST_DIR}/docker-bake.hcl" <<'HCL'
variable "ANDROID_PLATFORM_VERSION" {
  default = "37"
}
HCL
    assert_status_code 0 'run_resolve_step "Resolve Android API level"'
    assert_equals 'api=37' "$(cat "$GITHUB_OUTPUT")"
}

test_release_resolves_android_ndk_major() {
    assert_status_code 0 'run_resolve_step "Resolve Android NDK version"'
    assert_equals 'ndk=30' "$(cat "$GITHUB_OUTPUT")"
}
