# :lint

Linting toolbox. Inherits all `:core` tools.

## Base

`FROM ghcr.io/driftsys/dock:core` (via build context)

## Installed tools

| Tool                 | Install method           | Purpose                          |
| -------------------- | ------------------------ | -------------------------------- |
| shellcheck           | apk                      | Shell script linter              |
| editorconfig-checker | apk                      | EditorConfig rule checker        |
| git-std              | binary (GitHub releases) | Conventional commits + git hooks |

## Platform note

`git-std` releases only provide a Linux x86_64 binary. This image is
therefore built for `linux/amd64` only.

## Usage in CI

```yaml
jobs:
  lint:
    runs-on: ubuntu-latest
    container: ghcr.io/driftsys/dock:lint
    steps:
      - uses: actions/checkout@v4
      - run: shellcheck scripts/*.sh
      - run: editorconfig-checker
      - run: git std check
```

## Build arguments

| Argument          | Default | Description                |
| ----------------- | ------- | -------------------------- |
| `GIT_STD_VERSION` | `0.7.0` | git-std release to install |

## Approximate size

~44 MB (Alpine, linux/amd64 only)
