#!/usr/bin/env bash
# Deno tests — presence + sanity for the :deno image.
# Sources test_core.sh so all core tests also run.

# shellcheck source=tests/test_core.sh
source "$(dirname "$0")/test_core.sh"

# ---------------------------------------------------------------------------
# Presence tests
# ---------------------------------------------------------------------------

test_deno_present() { assert "command -v deno"; }

# ---------------------------------------------------------------------------
# CA bundle tests
# ---------------------------------------------------------------------------

test_deno_cert_env() {
  assert_equals "/etc/ssl/certs/ca-certificates.crt" "$DENO_CERT"
}

# ---------------------------------------------------------------------------
# Sanity tests
# ---------------------------------------------------------------------------

test_deno_version() {
  assert "deno --version"
}

test_deno_uses_lts_release_line() {
  assert_equals "2.9" "$(deno eval 'console.log(Deno.version.deno.split(".").slice(0, 2).join("."))')"
}

test_deno_eval() {
  result="$(deno eval 'console.log(1+1)')"
  assert_equals "2" "$result"
}

test_deno_fixture_workflow() {
  local dir
  dir="$(mktemp -d)"
  cp -r /fixtures/deno/. "$dir/"

  deno lint "${dir}/main.ts"
  deno fmt --check "${dir}/main.ts"
  deno test "${dir}/main_test.ts"

  rm -rf "$dir"
}

# ---------------------------------------------------------------------------
# npx shim tests
# ---------------------------------------------------------------------------

test_npx_present() { assert "command -v npx"; }

test_npx_no_args_shows_usage() {
  # npx with no arguments should exit non-zero and print usage
  if npx 2>/dev/null; then
    fail "npx with no args should exit non-zero"
  fi
}

# ---------------------------------------------------------------------------
# npm shim tests
# ---------------------------------------------------------------------------

test_npm_present() { assert "command -v npm"; }

test_npm_no_args_shows_usage() {
  # npm with no arguments should exit non-zero and print usage
  if npm 2>/dev/null; then
    fail "npm with no args should exit non-zero"
  fi
}

test_npm_unsupported_command_errors() {
  if npm publish 2>/dev/null; then
    fail "npm shim should reject unsupported commands"
  fi
}

test_npm_init() {
  local dir
  dir="$(mktemp -d)"
  npm init "$dir"
  assert "[ -f ${dir}/main.ts ] || [ -f ${dir}/deno.json ]" \
    "npm init should scaffold a project"
  rm -rf "$dir"
}

# ---------------------------------------------------------------------------
# Manifest
# ---------------------------------------------------------------------------

test_manifest_has_deno() { assert_manifest_tool '.tools.deno'; }

# Run controlled child tests against the installed shim, not the source tree.
test_npx_argument_translation() {
  assert 'NPX_SHIM=/usr/local/bin/npx deno test --allow-all /tests/test_npx.ts'
}

test_npx_gitlab_ci_local_preview_without_node_or_npm_runtime() {
  assert_fails 'command -v node'
  assert_fails 'command -v nodejs'
  assert 'head -1 /usr/local/bin/npm | grep -Fx "#!/usr/bin/env -S deno run --allow-run"'
  local dir output status=0
  dir="$(mktemp -d)"
  printf 'preview-job:\n  script: echo "dock preview"\n' > "$dir/.gitlab-ci.yml"
  output="$(cd "$dir" && npx --yes --package=gitlab-ci-local@4.75.0 gitlab-ci-local --preview 2>"$dir/stderr")" || status=$?
  assert_equals 0 "$status"
  assert_matches 'preview-job' "$output"
  assert_matches 'dock preview' "$output"
  rm -rf "$dir"
}

# npm controlled-child coverage includes custom signal handlers and cleanup.
test_npm_argument_translation() {
  assert 'NPM_SHIM=/usr/local/bin/npm deno test --allow-all /tests/test_npm.ts'
}

test_npm_local_dependencies_and_node_tasks() {
  local dir output status=0
  dir="$(mktemp -d)"
  cp /fixtures/npm-project/* "$dir/"
  assert_fails 'command -v node'
  assert_fails 'command -v nodejs'
  assert "npm --prefix '$dir' install is-number@7.0.0 is-odd@3.0.1"
  assert "jq -e '.dependencies[\"is-number\"] and .dependencies[\"is-odd\"]' '$dir/package.json'"
  assert "npm install --prefix '$dir' --save-dev picocolors@1.1.1"
  assert "jq -e '.devDependencies.picocolors' '$dir/package.json'"
  assert "npm ci --prefix '$dir' --omit=dev"
  assert "npm uninstall --prefix '$dir' is-number is-odd picocolors"
  assert "jq -e '([(.dependencies // {}), (.devDependencies // {})] | map(length) | add) == 0' '$dir/package.json'"
  output="$(npm --prefix "$dir" run start -- 'argument with spaces' '' --flag)"
  assert "jq -e '.runtime | startswith(\"2.9.\")' <<< '$output'"
  assert "jq -e '.args == [\"argument with spaces\", \"\", \"--flag\"]' <<< '$output'"
  assert "npm run --prefix '$dir' --if-present missing-task"
  npm --prefix "$dir" run fail >"$dir/stdout" 2>"$dir/stderr" || status=$?
  assert_equals 37 "$status"
  assert "grep -Fx 'failure stdout' '$dir/stdout'"
  assert "grep -Fx 'failure stderr' '$dir/stderr'"
  rm -rf "$dir"
}

test_npm_global_install_and_uninstall() {
  local dir root output
  dir="$(mktemp -d)"
  root="$(mktemp -d)"
  printf 'preview-job:\n  script: echo "npm global preview"\n' > "$dir/.gitlab-ci.yml"
  git -C "$dir" init -q --initial-branch=main
  git -C "$dir" config user.name Test
  git -C "$dir" config user.email test@example.com
  git -C "$dir" commit -q --allow-empty -m fixture
  git -C "$dir" remote add origin https://example.com/dock/fixture.git
  git -C "$dir" update-ref refs/remotes/origin/main HEAD
  git -C "$dir" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
  assert 'npm install --global gitlab-ci-local@4.75.0'
  assert 'command -v gitlab-ci-local'
  output="$(cd "$dir" && gitlab-ci-local --preview)"
  assert_matches 'npm global preview' "$output"
  assert 'npm uninstall -g gitlab-ci-local'
  assert_fails 'command -v gitlab-ci-local'
  assert "npm install -g --prefix '$root' gitlab-ci-local@4.75.0"
  assert "test -x '$root/bin/gitlab-ci-local'"
  assert "npm rm -g --prefix '$root' gitlab-ci-local"
  assert "test ! -e '$root/bin/gitlab-ci-local'"
  rm -rf "$dir" "$root"
}
