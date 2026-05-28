# :lint

Linting toolbox. Inherits all `:deno` tools (including npx/npm shims).

## Base

| Variant          | Base                                       |
| ---------------- | ------------------------------------------ |
| Alpine (default) | `ghcr.io/driftsys/dock:deno` (build        |
|                  | context)                                   |
| Debian           | `ghcr.io/driftsys/dock:deno-debian` (build |
|                  | context)                                   |

## Installed tools

| Tool                 | Install method           | Purpose                          |
| -------------------- | ------------------------ | -------------------------------- |
| dprint               | binary (GitHub releases) | Fast code formatter (md/json/toml/yaml) |
| gomdlint             | binary (GitHub releases) | Markdown linter (40+ rules, auto-fix)   |
| shellcheck           | apk                      | Shell script linter              |
| editorconfig-checker | apk                      | EditorConfig rule checker        |
| git-std              | binary (GitHub releases) | Conventional commits + git hooks |

Because `:lint` inherits from `:deno`, you also have access to
`npx` and `npm` shims. This means any npm-based linter is available
without installing Node.js:

```bash
npx markdownlint-cli2 "**/*.md"
npx prettier --check "**/*.yaml"
```

## Platform note

`git-std` and `gomdlint` releases only provide Linux x86_64 binaries.
This image is built for `linux/amd64` only.

## Usage in CI

```yaml
jobs:
  lint:
    runs-on: ubuntu-latest
    container: ghcr.io/driftsys/dock:lint
    steps:
      - uses: actions/checkout@v4
      - run: dprint check
      - run: gomdlint lint
      - run: shellcheck scripts/*.sh
      - run: editorconfig-checker
      - run: git-std check
```

## Build arguments

| Argument           | Default  | Description                   |
| ------------------ | -------- | ----------------------------- |
| `DPRINT_VERSION`   | `0.54.0` | dprint release to install     |
| `GOMDLINT_VERSION` | `0.2.1`  | gomdlint release to install   |
| `GIT_STD_VERSION`  | `0.11.12`| git-std release to install    |

## Approximate size

| Variant | Size    |
| ------- | ------- |
| Alpine  | ~155 MB |
| Debian  | ~210 MB |
