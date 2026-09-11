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

| Tool                 | Install method                 | Purpose                                 |
| -------------------- | ------------------------------ | --------------------------------------- |
| dprint               | binary (GitHub releases)       | Fast code formatter (md/json/toml/yaml) |
| shellcheck           | apk                            | Shell script linter                     |
| editorconfig-checker | apk (Alpine) / binary (Debian) | EditorConfig rule checker               |

> `git-std` (conventional commits, changelog, versioning, git hooks) now
> ships in its own [`:std`](std.md) image, not `:lint`.

Because `:lint` inherits from `:deno`, you also have access to
`npx` and `npm` shims. This means any npm-based linter is available
without installing Node.js:

```bash
npx markdownlint-cli2 "**/*.md"
npx prettier --check "**/*.yaml"
```

## Platform note

`dprint` (both variants) and `editorconfig-checker` (Debian) are installed
as x86_64 binaries. This image is built for `linux/amd64` only.

## Usage in CI

```yaml
jobs:
  lint:
    runs-on: ubuntu-latest
    container: ghcr.io/driftsys/dock:lint
    steps:
      - uses: actions/checkout@v4
      - run: dprint check
      - run: npx markdownlint-cli2 "**/*.md"
      - run: shellcheck scripts/*.sh
      - run: editorconfig-checker
```

## Build arguments

| Argument         | Default  | Description               |
| ---------------- | -------- | ------------------------- |
| `DPRINT_VERSION` | `0.54.0` | dprint release to install |

## Approximate size

| Variant | Size    |
| ------- | ------- |
| Alpine  | ~92 MB  |
| Debian  | ~135 MB |
