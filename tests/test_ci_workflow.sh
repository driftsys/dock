#!/usr/bin/env bash
# Execute image detection against real changes in a temporary git repository.

# shellcheck source=tests/workflow_helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/workflow_helpers.sh"

setup_suite() {
    REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    WORKFLOW="$REPO_DIR/.github/workflows/ci.yml"
    DETECTION="$(yq -r '.jobs.detect.steps[] | select(.name == "Determine affected images") | .run' \
      "$WORKFLOW")"
}

setup() {
    TEST_DIR="$(mktemp -d)"
    git -C "$TEST_DIR" init -q
    git -C "$TEST_DIR" -c user.name=Test -c user.email=test@example.com \
      commit -q --allow-empty -m baseline
    BASE_SHA="$(git -C "$TEST_DIR" rev-parse HEAD)"
    export GITHUB_OUTPUT="$TEST_DIR/output"
}

teardown() { rm -rf "$TEST_DIR"; }

run_detection() {
    local path="$1" body="$DETECTION"
    mkdir -p "$TEST_DIR/$(dirname "$path")"
    printf '%s\n' changed > "$TEST_DIR/$path"
    git -C "$TEST_DIR" add "$path"
    git -C "$TEST_DIR" -c user.name=Test -c user.email=test@example.com \
      commit -q -m change
    body="${body//"\${{ github.event_name }}"/pull_request}"
    body="${body//"\${{ github.event.pull_request.base.sha }}"/$BASE_SHA}"
    (cd "$TEST_DIR" && bash -e -o pipefail -c "$body")
}

test_ci_executes_rust_and_polyglot_on_both_architectures() {
    assert 'run_detection images/rust/Dockerfile'
    CI_MATRIX="$(sed -n 's/^matrix=//p' "$GITHUB_OUTPUT")"
    assert "jq -e '.include | length == 6' <<< \"\$CI_MATRIX\""
    local image
    for image in rust rust-debian polyglot-debian; do
        assert "jq -e --arg image '$image' '[.include[] | select(.image == \$image)] | sort_by(.platform) == [
          {image: \$image, platform: \"linux/amd64\", runner: \"ubuntu-latest\"},
          {image: \$image, platform: \"linux/arm64\", runner: \"ubuntu-24.04-arm\"}]' <<< \"\$CI_MATRIX\""
    done
}

test_ci_does_not_build_images_for_prose_only_changes() {
    assert 'run_detection docs/images/rust.md'
    CI_MATRIX="$(sed -n 's/^matrix=//p' "$GITHUB_OUTPUT")"
    assert_equals '{"include":[]}' "$CI_MATRIX"
    assert "grep -Fx 'any=false' '$GITHUB_OUTPUT'"
}

test_ci_runs_image_checks_when_workflow_changes() {
    assert 'run_detection .github/workflows/ci.yml'
    CI_MATRIX="$(sed -n 's/^matrix=//p' "$GITHUB_OUTPUT")"
    assert "jq -e '.include | any(.image == \"core\") and any(.image == \"rust\" and .platform == \"linux/arm64\")' <<< \"\$CI_MATRIX\""
}

test_ci_consumes_native_runner_and_platform_matrix() {
    assert 'run_detection images/rust/Dockerfile'
    local matrix runner platform runner_template set_template platform_template
    matrix="$(sed -n 's/^matrix=//p' "$GITHUB_OUTPUT")"
    runner_template="$(yq -r '.jobs.build-test.runs-on' "$WORKFLOW")"
    set_template="$(yq -r '.jobs.build-test.steps[] | select(.name == "Build image") | .with.set' "$WORKFLOW")"
    platform_template="$(printf '%s\n' "$set_template" | sed -n 's/^\*\.platform=//p')"
    while IFS=$'\t' read -r runner platform; do
        assert_equals "$runner" "$(workflow_matrix_value "$runner_template" runner "$runner")"
        assert_equals "$platform" "$(workflow_matrix_value "$platform_template" platform "$platform")"
    done < <(jq -r '.include[] | [.runner, .platform] | @tsv' <<< "$matrix")
}

test_ci_runs_image_checks_when_health_workflow_changes() {
    assert 'run_detection .github/workflows/health.yml'
    local matrix
    matrix="$(sed -n 's/^matrix=//p' "$GITHUB_OUTPUT")"
    assert "jq -e '.include | any(.image == \"core\") and any(.image == \"rust\" and .platform == \"linux/arm64\")' <<< \"\$matrix\""
    assert "grep -Fx 'any=true' '$GITHUB_OUTPUT'"
}

test_ci_schedules_offline_coverage_for_all_affected_images() {
    local coverage_predicate image
    coverage_predicate="$(yq -r '.jobs.build-test.steps[] | select(.name == "Run offline coverage tests") | .if' "$WORKFLOW")"
    for image in rust rust-debian polyglot-debian; do
        assert "workflow_selects_image $(printf '%q' "$coverage_predicate") '$image'"
    done
    assert_fails "workflow_selects_image $(printf '%q' "$coverage_predicate") core"
}
