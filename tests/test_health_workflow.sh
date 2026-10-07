#!/usr/bin/env bash
# Host tests for the scheduled workflow. Requires mikefarah/yq v4.
# Docker records image references instead of pulling or running containers.

# shellcheck source=tests/workflow_helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/workflow_helpers.sh"

setup_suite() {
    REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    WORKFLOW="${REPO_DIR}/.github/workflows/health.yml"
    MATRIX="$(yq -r '.jobs.test.strategy.matrix | (.image[], .include[].image)' "$WORKFLOW")"
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
            printf '%s\n' "$*" >> "${DOCKER_CALLS}.args"
            if [[ "$command" == run && "$*" == *' tar -C /etc/ssl/certs -cf - .' ]]; then
                tar -cf - -T /dev/null
            fi
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
        tested="$(sed -n 's/^run //p' "$DOCKER_CALLS" | sort -u)"
        assert_not_equals "" "$pulled" "Workflow must pull $image"
        assert_equals "$pulled" "$tested" \
            "Workflow and runner must use the same tag for $image"
    done <<< "$MATRIX"
}


test_health_runs_readonly_certificate_check() {
    local image
    for image in python-debian polyglot-debian; do
        : > "${DOCKER_CALLS}.args"
        assert_status_code 0 "run_workflow_step \"Run tests\" \"$image\""
        assert "grep -F -- 'tar -C /etc/ssl/certs -cf - .' '${DOCKER_CALLS}.args'"
        assert "grep -F -- ':/etc/ssl/certs:ro' '${DOCKER_CALLS}.args'"
        assert "grep -F -- ' -e DOCK_TEST_READONLY_CA=1 ' '${DOCKER_CALLS}.args'"
        assert "grep -F -- ' -p test_uv_corporate_ca ' '${DOCKER_CALLS}.args'"
    done
}


test_health_schedules_rust_on_native_arm64() {
    local image runners
    for image in rust rust-debian polyglot-debian; do
        runners="$(IMAGE="$image" yq -r '
          .jobs.test.strategy.matrix.include[]
          | select(.image == strenv(IMAGE)) | .runner' "$WORKFLOW")"
        assert_equals 'ubuntu-24.04-arm' "$runners"
    done
}

test_health_executes_coverage_without_networking() {
    local image expected
    for image in rust rust-debian polyglot-debian; do
        case "$image" in
            rust) expected=rust-alpine ;;
            *) expected="$image" ;;
        esac
        : > "$DOCKER_CALLS"
        : > "${DOCKER_CALLS}.args"
        assert_status_code 0 "run_workflow_step 'Run offline coverage tests' '$image'"
        assert_equals "run ghcr.io/driftsys/dock:$expected" "$(cat "$DOCKER_CALLS")"
        assert "grep -F -- '--network none' '${DOCKER_CALLS}.args'"
        assert "grep -F -- '-p test_coverage|test_llvm_tools' '${DOCKER_CALLS}.args'"
    done
}

test_health_retains_amd64_alongside_arm64() {
    local runners
    # An explicit original runner axis prevents include from overwriting it.
    runners="$(yq -r '.jobs.test.strategy.matrix.runner[]' "$WORKFLOW")"
    assert_equals 'ubuntu-latest' "$runners"
    local image
    for image in rust rust-debian polyglot-debian; do
        assert "IMAGE='$image' yq -e '.jobs.test.strategy.matrix.image | any_c(. == strenv(IMAGE))' '$WORKFLOW'"
    done
}

test_health_consumes_both_native_runners() {
    local runner template
    template="$(yq -r '.jobs.test.runs-on' "$WORKFLOW")"
    for runner in ubuntu-latest ubuntu-24.04-arm; do
        assert_equals "$runner" "$(workflow_matrix_value "$template" runner "$runner")"
    done
}

test_health_schedules_offline_coverage_for_all_affected_images() {
    local coverage_predicate image
    coverage_predicate="$(yq -r '.jobs.test.steps[] | select(.name == "Run offline coverage tests") | .if' "$WORKFLOW")"
    for image in rust rust-debian polyglot-debian; do
        assert "workflow_selects_image $(printf '%q' "$coverage_predicate") '$image'"
    done
    assert_fails "workflow_selects_image $(printf '%q' "$coverage_predicate") core"
}
