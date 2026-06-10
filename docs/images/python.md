# :python

Python 3 runtime with ruff. Inherits all `:core-debian` tools.

**Debian-only.** Python wheels (`manylinux`) target glibc, so `:python` has no
Alpine variant — the bare `:python` tag and `:python-debian` are the same image.

## Base

| Variant | Base                                                |
| ------- | --------------------------------------------------- |
| Debian  | `ghcr.io/driftsys/dock:core-debian` (build context) |

## Installed tools

| Tool    | Install method    | Purpose              |
| ------- | ----------------- | -------------------- |
| python3 | apt               | Python 3 interpreter |
| pip     | apt (python3-pip) | Package installer    |
| ruff    | pip               | Linter and formatter |

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
| Debian  | ~104 MB |
