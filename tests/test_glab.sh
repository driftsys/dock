#!/usr/bin/env bash
# GitLab reporting tests, including the inherited Deno toolbox.
# shellcheck source=tests/test_deno.sh
source "$(dirname "$0")/test_deno.sh"

test_glab_present() { assert 'command -v glab'; }
test_sarif_converter_present() { assert 'command -v sarif-converter'; }
test_reviewdog_present() { assert 'command -v reviewdog'; }
test_tap2junit_present() { assert 'command -v tap2junit'; }
test_glab_version() { assert 'glab version'; }
test_glab_api_help() { assert 'glab api --help'; }
test_reporting_manifest() {
  local tool
  for tool in glab sarif-converter reviewdog tap2junit deno; do
    assert_manifest_tool ".tools[\"$tool\"]"
  done
  assert_equals "$(glab version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)" "$(jq -r '.tools.glab' /etc/dock/manifest.json)"
  assert_equals "$(sarif-converter --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)" "$(jq -r '.tools["sarif-converter"]' /etc/dock/manifest.json)"
  assert_equals "$(reviewdog -version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)" "$(jq -r '.tools.reviewdog' /etc/dock/manifest.json)"
  assert_equals "$(tap2junit --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)" "$(jq -r '.tools.tap2junit' /etc/dock/manifest.json)"
}

test_sarif_to_codequality() {
  local report
  report="$(mktemp)"
  assert_status_code 0 "sarif-converter --type codequality /fixtures/reporting/findings.sarif '$report'"
  assert "jq -e 'type == \"array\" and length == 2 and all(.[]; .check_name == \"fixture-rule\" and .location.path == \"fixture.sh\" and (.fingerprint | type == \"string\"))' '$report'"
  assert "jq -e 'map({description, line: .location.lines.begin}) == [{description: \"UNCHANGED_FINDING\", line: 1}, {description: \"ADDED_FINDING\", line: 3}] and all(.[]; (.fingerprint | length) > 0) and ([.[].fingerprint] | unique | length) == 2' '$report'"
  rm -f "$report"
}

test_reviewdog_filters_added_lines() {
  local dir output status=0
  dir="$(mktemp -d)"
  git -C "$dir" init -q
  printf 'echo first\necho second\necho old\n' > "$dir/fixture.sh"
  git -C "$dir" add fixture.sh
  git -C "$dir" -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm fixture
  printf 'echo first\necho second\necho changed\n' > "$dir/fixture.sh"
  output="$(cd "$dir" && reviewdog -f=sarif -reporter=local -filter-mode=added \
    -diff='git diff --no-ext-diff --unified=0 HEAD' < /fixtures/reporting/findings.sarif 2>&1)" || status=$?
  assert_equals 0 "$status"
  assert_matches ADDED_FINDING "$output"
  assert_not_matches UNCHANGED_FINDING "$output"
  rm -rf "$dir"
}

test_tap2junit_fixture() {
  local dir
  dir="$(mktemp -d)"
  assert "tap2junit --name 'fixture & \"suite\"' < /fixtures/reporting/results.tap > '$dir/report.xml'"
  assert "yq -p xml --xml-strict-mode --xml-raw-token=false -o json '$dir/report.xml' > '$dir/report.json'"
  assert "jq --arg suite 'fixture & \"suite\"' -e '.testsuites.testsuite | .[\"+@name\"] == \$suite and .[\"+@tests\"] == \"4\" and .[\"+@failures\"] == \"1\" and .[\"+@skipped\"] == \"2\"' '$dir/report.json'"
  assert "jq --arg suite 'fixture & \"suite\"' -e '.testsuites.testsuite.testcase | all(.[]; .[\"+@classname\"] == \$suite) and map(.[\"+@name\"]) == [\"passes\", \"fails\", \"skipped\", \"pending\"] and (.[0] | has(\"failure\") or has(\"skipped\") | not) and .[1].failure[\"+content\"] == \"message: expected <one> & got two\" and .[2].skipped[\"+@message\"] == \"unavailable\" and .[3].skipped[\"+@message\"] == \"implement\"' '$dir/report.json'"
  rm -rf "$dir"
}

test_tap2junit_rejects_partial_cli_input() {
  local dir
  dir="$(mktemp -d)"
  printf '1..2\nok 1 - partial\n' > "$dir/partial.tap"
  assert_status_code 2 "tap2junit < '$dir/partial.tap' > '$dir/report.xml' 2> '$dir/error.log'"
  assert "[ ! -s '$dir/report.xml' ]"
  assert "grep -q 'TAP plan' '$dir/error.log'"
  rm -rf "$dir"
}

test_tap2junit_real_bash_unit() {
  local dir status=0
  dir="$(mktemp -d)"
  # Recorded using this repository's vendored bash_unit and fixture script.
  cp /fixtures/reporting/bash_unit.tap "$dir/results.tap"
  # TAP output in bash_unit requires GNU sed's unbuffered mode.
  if sed --version 2>/dev/null | grep -Fq 'sed (GNU sed)'; then
    bash /tests/bash_unit -f tap /fixtures/reporting/bash_unit.sh > "$dir/results.tap" || status=$?
    assert_equals 1 "$status" 'Fixture must contain a real failed test'
  fi
  assert "tap2junit < '$dir/results.tap' > '$dir/report.xml'"
  assert "yq -p xml --xml-strict-mode --xml-raw-token=false -o json '$dir/report.xml' > '$dir/report.json'"
  assert "jq -e '.testsuites.testsuite.testcase | map({name: .[\"+@name\"], failed: has(\"failure\")}) == [{name: \"test_fixture_failure\", failed: true}, {name: \"test_fixture_success\", failed: false}]' '$dir/report.json'"
  rm -rf "$dir"
}

test_tap2junit_unit_suite() {
  assert 'deno test /tests/test_tap2junit.ts'
}

test_reporting_tls_trust() {
  local dir pid port output status=0
  dir="$(mktemp -d)"
  deno run --allow-net --allow-read /fixtures/tls/server.ts > "$dir/server.log" 2>&1 &
  pid=$!
  for _ in $(seq 1 100); do
    if [ -s "$dir/server.log" ]; then break; fi
    sleep 0.05
  done
  port="$(head -n1 "$dir/server.log")"
  if ! [[ "$port" =~ ^[0-9]+$ ]]; then
    kill "$pid" 2>/dev/null || true
    fail 'TLS fixture did not start'
    return
  fi
  glab config set api_host "localhost:$port" --host localhost
  output="$(GITLAB_TOKEN=fixture glab api --hostname localhost version 2>&1)" || status=$?
  assert_not_equals 0 "$status" 'Untrusted CA must be rejected'
  assert_matches 'certificate' "$output"
  output="$(CI_API_V4_URL="https://localhost:$port/api/v4" \
    CI_PROJECT_NAMESPACE=fixture CI_PROJECT_NAME=project \
    CI_PROJECT_ID=1 CI_MERGE_REQUEST_IID=1 CI_COMMIT_SHA=fixture \
    REVIEWDOG_GITLAB_API_TOKEN=fixture reviewdog -f=sarif \
    -reporter=gitlab-mr-discussion < /fixtures/reporting/findings.sarif 2>&1)" || true
  assert_matches 'certificate signed by unknown authority' "$output"
  mkdir "$dir/ca"
  cp /fixtures/tls/ca.crt "$dir/ca/"
  assert "dock-bootstrap '$dir/ca'"
  assert "GITLAB_TOKEN=fixture glab api --hostname localhost version"
  # An unavailable MR returns an API error after TLS has succeeded.
  output="$(CI_API_V4_URL="https://localhost:$port/api/v4" \
    CI_PROJECT_NAMESPACE=fixture CI_PROJECT_NAME=project \
    CI_PROJECT_ID=1 CI_MERGE_REQUEST_IID=1 CI_COMMIT_SHA=fixture \
    REVIEWDOG_GITLAB_API_TOKEN=fixture reviewdog -f=sarif \
    -reporter=gitlab-mr-discussion < /fixtures/reporting/findings.sarif 2>&1)" || true
  assert_not_matches 'certificate signed by unknown authority' "$output"
  assert "grep -q '/api/v4/projects/fixture' '$dir/server.log'"
  kill "$pid"
  wait "$pid" 2>/dev/null || true
  rm -rf "$dir"
}
