# :glab

GitLab reporting and merge-request automation. Alpine inherits `:deno-alpine`;
Debian inherits `:deno-debian`. Both support amd64 and arm64. Bare `:glab`
selects Alpine. All core and Deno tools remain available.

## Installed tools

| Tool            | Version | Installation            | Purpose                           |
| --------------- | ------- | ----------------------- | --------------------------------- |
| glab            | 1.120.0 | Official release binary | GitLab CLI and API                |
| sarif-converter | 0.9.4   | Official static binary  | Code Quality and SAST             |
| reviewdog       | 0.21.2  | Official static binary  | Diff filtering and MR discussions |
| tap2junit       | 1.0.0   | Local Deno script       | TAP 13 to JUnit                   |

`GLAB_VERSION`, `SARIF_CONVERTER_VERSION`, and `REVIEWDOG_VERSION` are build
arguments. The manifest also preserves inherited Deno and core versions.

Producer jobs in `:lint`, `:rust`, or another language image publish
`findings/*.sarif` and `results/*.tap` artifacts. They need no bot token. Run
the report job on merge requests and the default branch: GitLab compares Code
Quality results against the target branch's report.

## Report stage

This example consumes artifacts from producer jobs in earlier stages. Add
`report` and `review` after those stages in your pipeline's `stages` list.

```yaml
report:
  stage: report
  image: ghcr.io/driftsys/dock:glab
  rules:
    - when: always
  script:
    - dock-bootstrap
    - if [ -f /etc/dock/ca.env ]; then . /etc/dock/ca.env; fi
    - mkdir -p reports
    - |
      set -- findings/*.sarif
      if [ -f "$1" ]; then
        sarif-converter --type codequality "$@" reports/codequality.json
      else
        printf '[]\n' > reports/codequality.json
      fi
    - |
      for file in results/*.tap; do
        [ -f "$file" ] || continue
        tap2junit --name "$(basename "$file" .tap)" < "$file" \
          > "reports/$(basename "$file" .tap).xml"
      done
  artifacts:
    when: always
    reports:
      codequality: reports/codequality.json
      junit: reports/*.xml
```

The converter accepts several SARIF input files before the output path. For
SAST, use `sarif-converter --type sast input.sarif reports/sast.json`. Use
`--src-root "$CI_PROJECT_DIR"` when results contain absolute paths.

## Merge-request review

Create a project access token with `api` scope and a role that can create MR
discussions. Store it as a masked CI variable `REVIEW_BOT_TOKEN`, scoped to the
`mr-review` environment. Only this job declares that environment; producer and
report jobs do not receive the token. Run token-bearing jobs only for trusted
project merge requests. Fork pipelines need a separate trusted review policy.
Never print the token or disable TLS verification.

```yaml
review:
  stage: review
  image: ghcr.io/driftsys/dock:glab
  environment:
    name: mr-review
  variables:
    GIT_DEPTH: "0"
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event" && $CI_MERGE_REQUEST_SOURCE_PROJECT_ID == $CI_PROJECT_ID'
  script:
    - dock-bootstrap
    - if [ -f /etc/dock/ca.env ]; then . /etc/dock/ca.env; fi
    - export GITLAB_HOST="$CI_SERVER_HOST"
    - export GITLAB_TOKEN="$REVIEW_BOT_TOKEN"
    - export REVIEWDOG_GITLAB_API_TOKEN="$REVIEW_BOT_TOKEN"
    - git fetch origin "$CI_MERGE_REQUEST_TARGET_BRANCH_NAME"
    - |
      status=0
      for file in findings/*.sarif; do
        [ -f "$file" ] || continue
        reviewdog -f=sarif -reporter=gitlab-mr-discussion \
          -filter-mode=added -fail-level=warning < "$file" || status=1
      done
      exit "$status"
```

reviewdog 0.21.2 uses `-fail-level`, supports one SARIF document per invocation,
and computes the MR diff locally using GitLab's target-branch information. Fetch
target history as above. It reads `CI_API_V4_URL` for the GitLab API. Set
`GITLAB_HOST` explicitly for glab on self-managed GitLab, including the port
when required. Danger-style TypeScript scripts can run with `deno run` in a
separate MR-only job with `allow_failure: true`.

## TAP conversion

`tap2junit [--name SUITE]` reads stdin and writes JUnit XML to stdout. It
supports flat TAP 13 streams with leading or trailing plans, failed-test YAML
diagnostics, SKIP, and TODO. Both directives produce skipped cases. Failed test
results remain failures in XML; conversion itself exits zero. Malformed plans,
incomplete diagnostics, bailouts, and nested subtests exit two without producing
a report. This prevents partial runs appearing green. The command supports real
`bash_unit -f tap` output and needs no network or third-party packages. Tests,
diagnostics, and suite names are XML-escaped.

## Corporate certificates

glab and reviewdog use Go's system trust and `SSL_CERT_FILE`, inherited from
core. Run `dock-bootstrap`; source `/etc/dock/ca.env` when the trust store is
read-only. Deno's inherited `DENO_CERT` follows the same bundle.

Upstream references: [glab](https://docs.gitlab.com/cli/),
[SARIF converter](https://gitlab.com/ignis-build/sarif-converter), and
[reviewdog](https://github.com/reviewdog/reviewdog/tree/v0.21.2).
