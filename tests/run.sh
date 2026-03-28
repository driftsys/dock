#!/usr/bin/env bash
# tests/run.sh — bash_unit test runner for driftsys/dock images.
#
# Usage:
#   bash tests/run.sh           # run tests for all built images
#   bash tests/run.sh core      # run tests for the core image only
#
# Images must be built locally first (just build).
# Tests mount into containers — images contain no test code.

set -euo pipefail

REGISTRY="${REGISTRY:-ghcr.io/driftsys/dock}"
TEST_TIMEOUT="${TEST_TIMEOUT:-300}" # 5 minutes per image
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURES_DIR="${TESTS_DIR}/fixtures"
# Pass -f tap via BASH_UNIT_FLAGS to get TAP output (used by CI for reports).
BASH_UNIT_FLAGS="${BASH_UNIT_FLAGS:-}"

# Map image name → test script
declare -A TEST_SCRIPTS=(
    [core]="test_core.sh"
    [rust]="test_rust.sh"
    [deno]="test_deno.sh"
    [node]="test_node.sh"
    [python]="test_python.sh"
    [polyglot]="test_polyglot.sh"
    [lint]="test_lint.sh"
    [core-debian]="test_core.sh"
    [rust-debian]="test_rust.sh"
    [deno-debian]="test_deno.sh"
    [node-debian]="test_node.sh"
    [python-debian]="test_python.sh"
    [polyglot-debian]="test_polyglot.sh"
)

run_image_tests() {
    local image="$1"
    local script="${TEST_SCRIPTS[$image]:-}"

    if [[ -z "$script" ]]; then
        echo "ERROR: unknown image: ${image}" >&2
        return 1
    fi

    local tag="${REGISTRY}:${image}"
    echo "=== Testing ${tag} ==="

    # shellcheck disable=SC2086
    timeout "${TEST_TIMEOUT}" \
      docker run --rm \
        -v "${TESTS_DIR}:/tests:ro" \
        -v "${FIXTURES_DIR}:/fixtures:ro" \
        "${tag}" \
        bash /tests/bash_unit ${BASH_UNIT_FLAGS} "/tests/${script}"
}

# If an image name is passed, run only that image; otherwise run all.
if [[ $# -gt 0 ]]; then
    run_image_tests "$1"
else
    for image in core rust deno node python polyglot lint; do
        run_image_tests "$image"
    done
fi
