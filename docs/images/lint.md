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

| Tool                 | Install method                 | Purpose                          |
| -------------------- | ------------------------------ | -------------------------------- |
| gitleaks             | binary (GitHub releases)       | Secret and credential scanner    |
| hadolint             | binary (GitHub releases)       | Dockerfile linter                |
| shellcheck           | apk                            | Shell script linter              |
| shfmt                | apk (Alpine) / binary (Debian) | Shell script formatter           |
| editorconfig-checker | apk (Alpine) / binary (Debian) | EditorConfig rule checker        |
| git-std              | binary (GitHub releases)       | Conventional commits + git hooks |
| prim                 | binary (GitHub releases)       | Repository formatter and linter  |

## Platform note

The lint-specific binaries currently provide Linux x86_64 builds. This
image is built for `linux/amd64` only.

## Usage in CI

```yaml
jobs:
  lint:
    runs-on: ubuntu-latest
    container: ghcr.io/driftsys/dock:lint
    steps:
      - uses: actions/checkout@v4
      - run: prim lint
      - run: gitleaks git --redact
      - run: shellcheck scripts/*.sh
      - run: editorconfig-checker
      - run: git-std check
```

## Build arguments

| Argument           | Default   | Description                 |
| ------------------ | --------- | --------------------------- |
| `GIT_STD_VERSION`  | `0.11.19` | git-std release to install  |
| `GITLEAKS_VERSION` | `8.30.1`  | gitleaks release to install |
| `HADOLINT_VERSION` | `2.15.1`  | hadolint release to install |
| `PRIM_VERSION`     | `0.9.1`   | prim release to install     |
| `SHFMT_VERSION`    | `3.14.1`  | shfmt release to install    |

## Approximate size

| Variant | Size    |
| ------- | ------- |
| Alpine  | ~145 MB |
| Debian  | ~200 MB |
