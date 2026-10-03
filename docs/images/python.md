# :python

Python 3 runtime with uv, uvx, and Ruff. Inherits all `:core-debian` tools.

**Debian-only.** Python wheels (`manylinux`) target glibc, so `:python` has no
Alpine variant — the bare `:python` tag and `:python-debian` are the same image.

## Base

| Variant | Base                                                |
| ------- | --------------------------------------------------- |
| Debian  | `ghcr.io/driftsys/dock:core-debian` (build context) |

## Installed tools

| Tool    | Install method        | Purpose                                  |
| ------- | --------------------- | ---------------------------------------- |
| python3 | apt                   | Python 3 interpreter                     |
| pip     | apt (python3-pip)     | Package installer                        |
| uv, uvx | Official Astral image | Script and project dependency management |
| ruff    | Official Astral image | Linter and formatter                     |

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

## Dependency management

`uv` and `uvx` are pinned to `0.12.22`; Ruff is pinned to `0.16.10`. Their
binaries are copied from Astral's official multiarch images. The system Python
and pip remain installed, without pip modifying distribution packages.
`UV_VERSION` and `RUFF_VERSION` are build arguments.

Use the project's checked-in lockfile and cache uv downloads across CI runs:

```bash
export UV_CACHE_DIR="$CI_PROJECT_DIR/.uv-cache"
uv sync --frozen
uv run --frozen pytest
```

Cache `.uv-cache/` using `uv.lock` as part of the cache key. uv defaults to
`UV_LINK_MODE=copy`, which avoids hardlink warnings across container mounts.
`UV_PYTHON_DOWNLOADS=never` makes uv use the image's Python. Choose a compatible
Python requirement in your project or script; uv fails if none is available.

PEP 723 scripts can declare dependencies inline without manual venv setup:

```python
# /// script
# dependencies = ["requests==2.32.5"]
# ///
import requests

print(requests.get("https://example.com", timeout=30).status_code)
```

Run the script with `uv run script.py`. `uvx` runs a tool in an isolated
environment; pin the package version, for example
`uvx --from ruff==0.16.10 ruff --version`.

## GitLab reporting

Install test dependencies from your project lockfile, then capture reports:

```bash
mkdir -p findings results
uv sync --frozen
ruff check --output-format sarif . > findings/ruff.sarif || true
uv run --frozen pytest --junitxml=results/pytest.xml
```

Upload both directories as artifacts with `when: always`. The
[GitLab reporting image](glab.md) consumes Ruff SARIF for Code Quality and MR
threads. GitLab accepts the pytest JUnit report directly.

## Corporate certificates

uv uses `UV_SYSTEM_CERTS=true` and the inherited `SSL_CERT_FILE` bundle. Run
`dock-bootstrap` before resolving packages, and source `/etc/dock/ca.env` when
the system trust store is read-only. The pinned uv release calls the setting
`UV_SYSTEM_CERTS`; its former `UV_NATIVE_TLS` setting is deprecated. See
[corporate environments](../extending.md#corporate-environments) and
[Astral's certificate documentation](https://docs.astral.sh/uv/concepts/authentication/certificates/).

## Approximate size

Compressed download size for `linux/amd64`, measured on 2026-10-03.

| Variant | Size    |
| ------- | ------- |
| Debian  | ~138 MB |
