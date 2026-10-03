#!/usr/bin/env bash
# Host tests for the scheduled workflow. Requires mikefarah/yq v4.
# Docker records image references instead of pulling or running containers.

setup_suite() {
    REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    WORKFLOW="${REPO_DIR}/.github/workflows/health.yml"
    MATRIX="$(yq -r '.jobs.test.strategy.matrix.image[]' "$WORKFLOW")"
}

setup() {
    TEST_DIR="$(mktemp -d)"
    export DOCKER_CALLS="${TEST_DIR}/docker-calls"
    export PATH="${TEST_DIR}:${PATH}"
    cat > "${TEST_DIR}/docker" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
command="$1"
shift
for arg in "$@"; do
    case "$arg" in
        ghcr.io/driftsys/dock:*)
            printf '%s %s\n' "$command" "$arg" >> "$DOCKER_CALLS"
            exit 0
            ;;
    esac
done
exit 1
SH
    chmod +x "${TEST_DIR}/docker"
    # The recorder exits immediately; no container timeout is needed.
    cat > "${TEST_DIR}/timeout" <<'SH'
#!/usr/bin/env bash
shift
exec "$@"
SH
    chmod +x "${TEST_DIR}/timeout"
    ln -s "${REPO_DIR}/tests" "${TEST_DIR}/tests"
}

teardown() {
    rm -rf "$TEST_DIR"
}

run_workflow_step() {
    local step="$1" image="$2" body
    body="$(STEP_NAME="$step" yq -r \
        '.jobs.test.steps[] | select(.name == strenv(STEP_NAME)) | .run' \
        "$WORKFLOW")"
    body="${body//"\${{ matrix.image }}"/$image}"
    body="${body//"\${{ env.REGISTRY }}"/ghcr.io/driftsys/dock}"
    (cd "$TEST_DIR" && bash -e -o pipefail -c "$body")
}

test_health_retains_debian_only_targets() {
    local image
    for image in python-debian polyglot-debian; do
        assert "printf '%s\\n' \"\$MATRIX\" | grep -Fx -- '$image'" \
            "Scheduled tests must retain $image"
    done
}

test_health_schedules_glab_variants() {
    local image
    for image in glab glab-debian; do
        assert "printf '%s\\n' \"\$MATRIX\" | grep -Fx -- '$image'"
    done
}

test_health_matrix_entries_are_accepted_by_runner() {
    local image
    assert_not_equals "" "$MATRIX" "Health matrix must contain images"
    while IFS= read -r image; do
        assert_status_code 0 \
            "REGISTRY=ghcr.io/driftsys/dock bash \"${REPO_DIR}/tests/run.sh\" \"$image\"" \
            "Scheduled image $image must be accepted by the runner"
    done <<< "$MATRIX"
}

test_health_pulls_the_image_used_by_runner() {
    local image pulled tested
    while IFS= read -r image; do
        : > "$DOCKER_CALLS"
        assert_status_code 0 "run_workflow_step \"Pull image\" \"$image\""
        assert_status_code 0 "run_workflow_step \"Run tests\" \"$image\""

        pulled="$(sed -n 's/^pull //p' "$DOCKER_CALLS")"
        tested="$(sed -n 's/^run //p' "$DOCKER_CALLS")"
        assert_not_equals "" "$pulled" "Workflow must pull $image"
        assert_equals "$pulled" "$tested" \
            "Workflow and runner must use the same tag for $image"
    done <<< "$MATRIX"
}
