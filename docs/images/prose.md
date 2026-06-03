# :prose

English prose quality toolbox for technical documentation pipelines.
Inherits the `:core-debian` scripting foundation (git, jq, yq, curl, CA trust).

**Debian-only.** `vale` needs glibc + `libstdc++`, so `:prose` has no Alpine
variant — the bare `:prose` tag and `:prose-debian` are the same image.

## Base

| Variant | Base                                                |
| ------- | --------------------------------------------------- |
| Debian  | `ghcr.io/driftsys/dock:core-debian` (build context) |

## Installed tools

| Tool       | Install method           | Purpose                              |
| ---------- | ------------------------ | ------------------------------------ |
| vale       | binary (GitHub releases) | Configurable style and usage linter  |
| typos      | binary (GitHub releases) | Fast typo detector (no dictionaries) |
| harper-cli | binary (GitHub releases) | English grammar checker              |

## Pre-installed Vale style packs

Baked into `/usr/local/share/vale/styles/` so CI runs fully offline:

| Pack       | Source                        |
| ---------- | ----------------------------- |
| Microsoft  | `errata-ai/Microsoft` v0.14.2 |
| Google     | `errata-ai/Google` v0.6.3     |
| write-good | `errata-ai/write-good` v0.4.1 |
| proselint  | `errata-ai/proselint` v0.3.4  |

## Default configuration

A starter Vale config ships at `/etc/vale/.vale.ini` and is exposed
via the `VALE_CONFIG_PATH` environment variable:

```ini
StylesPath = /usr/local/share/vale/styles
MinAlertLevel = warning

[*.md]
BasedOnStyles = Vale, Microsoft, write-good, proselint
```

Projects override by dropping their own `.vale.ini` at the repository
root — Vale natively prefers project-local configuration.

## Tool philosophy

- **vale** — style and usage. Flags passive voice, weak words,
  terminology drift, and rule packs like Microsoft and Google style
  guides. Not a grammar checker.
- **typos** — known typo detection only. Catches obvious misspellings
  with very low false-positive rate. No dictionary maintenance: extend
  via a project-local `typos.toml`.
- **harper-cli** — real English grammar parser. Catches subject-verb
  agreement, article errors, prepositions, and tense issues that vale
  misses. Useful for documentation written by non-native English
  speakers.

The three tools cover orthogonal concerns. Run all three in CI for
full coverage.

## Usage in CI

```yaml
jobs:
  prose:
    runs-on: ubuntu-latest
    container: ghcr.io/driftsys/dock:prose
    steps:
      - uses: actions/checkout@v4
      - run: vale docs/
      - run: typos docs/
      - run: harper-cli lint "docs/**/*.md"
```

## Build arguments

| Argument                  | Default  | Description                   |
| ------------------------- | -------- | ----------------------------- |
| `VALE_VERSION`            | `3.14.2` | vale release to install       |
| `TYPOS_VERSION`           | `1.46.3` | typos release to install      |
| `HARPER_VERSION`          | `2.2.1`  | harper-cli release to install |
| `VALE_MICROSOFT_VERSION`  | `0.14.2` | Microsoft style pack release  |
| `VALE_GOOGLE_VERSION`     | `0.6.3`  | Google style pack release     |
| `VALE_WRITE_GOOD_VERSION` | `0.4.1`  | write-good style pack release |
| `VALE_PROSELINT_VERSION`  | `0.3.4`  | proselint style pack release  |

## Platform note

`:prose` is multi-arch: `linux/amd64` + `linux/arm64`. Unlike `:lint`
and `:pages`, all upstream tools publish arm64 binaries.

## Approximate size

| Variant | Size    |
| ------- | ------- |
| Debian  | ~106 MB |
