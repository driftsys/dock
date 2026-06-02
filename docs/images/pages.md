# :pages

Static-site and documentation toolbox for building books, PDFs, and
templated output. Inherits the `:core` scripting foundation (git, jq,
yq, curl, CA trust).

## Base

| Variant          | Base                                       |
| ---------------- | ------------------------------------------ |
| Alpine (default) | `ghcr.io/driftsys/dock:core` (build        |
|                  | context)                                   |
| Debian           | `ghcr.io/driftsys/dock:core-debian` (build |
|                  | context)                                   |

## Installed tools

| Tool          | Install method           | Purpose                              |
| ------------- | ------------------------ | ------------------------------------ |
| mdbook        | binary (GitHub releases) | Book / static-site generator         |
| typst         | binary (GitHub releases) | PDF / document compiler              |
| tera          | binary (GitHub releases) | Jinja2-like template engine          |
| mdbook-alerts | binary (GitHub releases) | GitHub-style `> [!NOTE]` blockquotes |
| mdbook-katex  | binary (GitHub releases) | Server-side LaTeX math rendering     |
| lychee        | binary (GitHub releases) | Fast async broken-link checker       |
| brotli        | apk / apt                | Brotli compression                   |
| Noto fonts    | apk / apt                | Fonts for typst PDF output           |

## Link checking

`lychee` replaces the older `mdbook-linkcheck` preprocessor. It is a
standalone CLI (native musl, no glibc runtime needed), so run it as a
separate step against the built book rather than as an `mdbook build`
hook:

```bash
mdbook build
lychee ./book
```

## Platform note

All tool binaries are pinned to x86_64, so this image is built for
`linux/amd64` only.

## Usage in CI

```yaml
jobs:
  docs:
    runs-on: ubuntu-latest
    container: ghcr.io/driftsys/dock:pages
    steps:
      - uses: actions/checkout@v4
      - run: mdbook build
      - run: lychee ./book
```

## Build arguments

| Argument                | Default        | Description                 |
| ----------------------- | -------------- | --------------------------- |
| `MDBOOK_VERSION`        | `0.5.3`        | mdbook release to install   |
| `TYPST_VERSION`         | `0.14.2`       | typst release to install    |
| `TERA_CLI_VERSION`      | `0.5.0`        | tera-cli release to install |
| `MDBOOK_ALERTS_VERSION` | `0.8.0`        | mdbook-alerts release       |
| `MDBOOK_KATEX_VERSION`  | `0.10.0-alpha` | mdbook-katex release        |
| `LYCHEE_VERSION`        | `0.24.2`       | lychee release to install   |

## Approximate size

| Variant | Size    |
| ------- | ------- |
| Alpine  | ~85 MB  |
| Debian  | ~140 MB |
