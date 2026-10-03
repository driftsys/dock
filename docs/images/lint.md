# :lint

Linting toolbox based directly on the core CI foundation.

## Base

| Variant          | Base                                       |
| ---------------- | ------------------------------------------ |
| Alpine (default) | `ghcr.io/driftsys/dock:core` (build        |
|                  | context)                                   |
| Debian           | `ghcr.io/driftsys/dock:core-debian` (build |
|                  | context)                                   |

## Installed tools

| Tool                 | Install method                    | Purpose                          |
| -------------------- | --------------------------------- | -------------------------------- |
| gitleaks             | binary (GitHub releases)          | Secret and credential scanner    |
| hadolint             | binary (GitHub releases)          | Dockerfile linter                |
| shellcheck-sarif     | source (Alpine) / binary (Debian) | ShellCheck JSON to SARIF         |
| shellcheck           | apk / apt                         | Shell script linter              |
| shfmt                | apk (Alpine) / binary (Debian)    | Shell script formatter           |
| editorconfig-checker | apk (Alpine) / binary (Debian)    | EditorConfig rule checker        |
| git-std              | binary (GitHub releases)          | Conventional commits + git hooks |
| prim                 | binary (GitHub releases)          | Repository formatter and linter  |

## Platform note

The lint-specific binaries currently provide Linux x86_64 builds. This image is
built for `linux/amd64` only.

## Usage in CI

```yaml
jobs:
  lint:
    runs-on: ubuntu-latest
    container: ghcr.io/driftsys/dock:lint
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - run: prim fmt --check
      - run: prim lint
      - run: gitleaks git --redact
      - run: shellcheck scripts/*.sh
      - run: editorconfig-checker
      - run: git std lint --range origin/main..HEAD
```

## Build arguments

| Argument                   | Default   | Description                 |
| -------------------------- | --------- | --------------------------- |
| `GIT_STD_VERSION`          | `0.11.19` | git-std release to install  |
| `GITLEAKS_VERSION`         | `8.30.1`  | gitleaks release to install |
| `HADOLINT_VERSION`         | `2.15.1`  | hadolint release to install |
| `PRIM_VERSION`             | `0.9.1`   | prim release to install     |
| `SHELLCHECK_SARIF_VERSION` | `0.8.0`   | ShellCheck SARIF converter  |
| `SHFMT_VERSION`            | `3.14.1`  | shfmt release to install    |

## SARIF artifacts

Producer jobs need no GitLab token. Create a findings directory and capture
reports, allowing warning exits so that every report is written:

```bash
mkdir -p findings
hadolint -f sarif images/core/Dockerfile > findings/hadolint.sarif || true
gitleaks git --report-format sarif --report-path findings/gitleaks.sarif || true
shellcheck -f json scripts/*.sh > findings/shellcheck.json || true
shellcheck-sarif < findings/shellcheck.json > findings/shellcheck.sarif
```

Upload `findings/*.sarif` as artifacts with `when: always`. The
[GitLab reporting image](glab.md) converts them to Code Quality and runs
reviewdog in a separate MR job that holds the API token.

`shellcheck-sarif` is pinned to `0.8.0`. Alpine builds its musl binary in a Rust
builder stage; Debian downloads the official glibc binary. The builder and its
compiler are absent from the final lint image.

## Approximate size

| Variant | Size    |
| ------- | ------- |
| Alpine  | ~145 MB |
| Debian  | ~200 MB |

Prim uses its non-strict defaults. No strict Markdown glob mappings or stricter
rule overrides are required.
