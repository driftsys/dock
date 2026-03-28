# dock

[![CI](https://github.com/driftsys/dock/actions/workflows/ci.yml/badge.svg)](https://github.com/driftsys/dock/actions/workflows/ci.yml)
[![Release](https://github.com/driftsys/dock/actions/workflows/release.yml/badge.svg)](https://github.com/driftsys/dock/actions/workflows/release.yml)
[![GHCR](https://img.shields.io/badge/ghcr.io-driftsys%2Fdock-blue?logo=github)](https://github.com/driftsys/dock/pkgs/container/dock)
[![Docker Hub](https://img.shields.io/docker/v/driftsys/dock?label=Docker%20Hub&logo=docker&sort=semver)](https://hub.docker.com/r/driftsys/dock)
[![Docs](https://img.shields.io/badge/docs-GitHub%20Pages-blue?logo=mdbook)](https://driftsys.github.io/dock)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)

Lean, layered CI Docker images published at `ghcr.io/driftsys/dock`.

Each image adds exactly one concern — scripting foundation, compilation
toolchain, or language runtime — so teams pick the smallest image that covers
their pipeline.

## Quick Start

```bash
# Pull and inspect any image
docker pull ghcr.io/driftsys/dock:core
docker run --rm ghcr.io/driftsys/dock:core bash --version

# Use in a GitHub Actions workflow
# .github/workflows/ci.yml
jobs:
  build:
    runs-on: ubuntu-latest
    container: ghcr.io/driftsys/dock:rust
    steps:
      - uses: actions/checkout@v4
      - run: cargo build --release
```

## Image Catalog

Every image ships in two variants:

| Tag             | Base                   | libc  | Use when                    |
| --------------- | ---------------------- | ----- | --------------------------- |
| `:image`        | `alpine:3.21`          | musl  | smallest footprint, default |
| `:image-debian` | `debian:bookworm-slim` | glibc | broader compatibility       |

### Available images

| Image       | From          | Size (Alpine) | Contents                                                     |
| ----------- | ------------- | ------------- | ------------------------------------------------------------ |
| `:core`     | `alpine:3.21` | ~32 MB        | Shell, Git, curl, jq, yq, gpg, …                             |
| `:rust`     | `:core`       | ~260 MB       | Rust stable, cargo, clippy, rustfmt, cargo-audit, cargo-deny |
| `:deno`     | `:core`       | ~120 MB       | Deno                                                         |
| `:node`     | `:core`       | ~115 MB       | Node.js LTS, npm                                             |
| `:python`   | `:core`       | ~55 MB        | Python 3, pip, ruff                                          |
| `:polyglot` | `:rust`       | ~382 MB       | Rust + Deno + Python 3                                       |
| `:lint`     | `:core`       | ~44 MB        | shellcheck, editorconfig-checker, git-std (linux/amd64 only) |

## Inheritance Tree

```
alpine:3.21
  └── :core              (~32 MB)
      ├── :rust          (~260 MB)
      │   └── :polyglot  (~382 MB)
      ├── :deno          (~120 MB)
      ├── :node          (~115 MB)
      └── :python        (~55 MB)
```

## Core Package List

All images include these tools from `:core`:

| Tool                    | Package                                    |
| ----------------------- | ------------------------------------------ |
| bash                    | bash                                       |
| curl                    | curl                                       |
| git                     | git                                        |
| git-lfs                 | git-lfs                                    |
| gpg                     | gnupg                                      |
| jq                      | jq                                         |
| yq                      | yq-go (Alpine) / mikefarah binary (Debian) |
| envsubst                | gettext / gettext-base                     |
| dotenv                  | dotenv (Alpine) / shell script (Debian)    |
| ssh                     | openssh-client                             |
| patch, find, tree, diff | patch, findutils, tree, diffutils          |
| zip, unzip              | zip, unzip                                 |
| tzdata                  | tzdata                                     |
| ca-certificates         | ca-certificates                            |

## Comparison

|               | dock:core     | cimg/base      | ubuntu-latest  |
| ------------- | ------------- | -------------- | -------------- |
| Size          | ~32 MB        | ~600 MB        | ~500 MB        |
| libc          | musl / glibc  | glibc          | glibc          |
| Git           | ✓             | ✓              | ✓              |
| jq/yq         | ✓             | —              | —              |
| Rust          | `:rust` image | manual install | manual install |
| Manifest JSON | ✓             | —              | —              |

## Tags

Tags follow the format `ghcr.io/driftsys/dock:{image}-{version}` where
`version` is the semantic release tag (e.g. `v1.2.3`). Floating tags
(`:core`, `:rust`, …) always point to the latest release.

See [docs/versioning.md](docs/versioning.md) for the full strategy.

## Documentation

Full documentation is available at
**[driftsys.github.io/dock](https://driftsys.github.io/dock)**.

- [Getting Started](https://driftsys.github.io/dock/getting-started.html)
- [Extending Images](https://driftsys.github.io/dock/extending.html)
- [Versioning Strategy](https://driftsys.github.io/dock/versioning.html)
- [Image Reference](https://driftsys.github.io/dock/images/core.html)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
