# :python

Python 3 runtime with ruff. Inherits all `:core` tools.

## Base

| Variant          | Base                                       |
| ---------------- | ------------------------------------------ |
| Alpine (default) | `ghcr.io/driftsys/dock:core` (build        |
|                  | context)                                   |
| Debian           | `ghcr.io/driftsys/dock:core-debian` (build |
|                  | context)                                   |

## Installed tools

| Tool    | Install method | Purpose              |
| ------- | -------------- | -------------------- |
| python3 | apk            | Python 3 interpreter |
| pip     | apk (py3-pip)  | Package installer    |
| ruff    | pip            | Linter and formatter |

## Usage in CI

```yaml
jobs:
  lint:
    runs-on: ubuntu-latest
    container: ghcr.io/driftsys/dock:python
    steps:
      - uses: actions/checkout@v4
      - run: ruff check .
      - run: ruff format --check .
```

## Approximate size

| Variant | Size    |
| ------- | ------- |
| Alpine  | ~55 MB  |
| Debian  | ~135 MB |
