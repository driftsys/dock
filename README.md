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

| Image          | From          | Alpine  | Debian  | Contents                                                             |
| -------------- | ------------- | ------- | ------- | -------------------------------------------------------------------- |
| `:core`        | `alpine:3.21` | ~32 MB  | ~80 MB  | Shell, Git, curl, jq, yq, gpg, …                                     |
| `:rust`        | `:core`       | ~260 MB | ~330 MB | Rust stable, cargo, clippy, rustfmt, cargo-audit, cargo-deny         |
| `:deno`        | `:core`       | ~120 MB | ~175 MB | Deno                                                                 |
| `:node`        | `:core`       | ~115 MB | ~195 MB | Node.js LTS, npm                                                     |
| `:python`      | `:core`       | ~55 MB  | ~135 MB | Python 3, pip, ruff                                                  |
| `:polyglot`    | `:rust`       | ~382 MB | ~460 MB | Rust + Deno + Python 3                                               |
| `:lint`        | `:core`       | ~44 MB  | —       | shellcheck, editorconfig-checker, git-std (linux/amd64 only)         |
| `:jvm`         | `:core`       | —       | ~290 MB | JDK 17 headless (Debian only)                                        |
| `:android`     | `:jvm`        | —       | ~485 MB | Android SDK (Debian only · pin: `:android-36-debian`)                |
| `:android-ndk` | `:android`    | —       | ~2.5 GB | NDK + Rust + cargo-ndk (Debian only · pin: `:android-ndk-27-debian`) |

## Inheritance Tree

### Alpine (default)

```
alpine:3.21
  └── :core              (~32 MB)
      ├── :rust          (~260 MB)
      │   └── :polyglot  (~382 MB)
      ├── :deno          (~120 MB)
      ├── :node          (~115 MB)
      └── :python        (~55 MB)
```

### Debian

```
debian:bookworm-slim
  └── :core-debian              (~80 MB)
      ├── :rust-debian          (~330 MB)
      │   └── :polyglot-debian  (~460 MB)
      ├── :deno-debian          (~175 MB)
      ├── :node-debian          (~195 MB)
      ├── :python-debian        (~135 MB)
      └── :jvm-debian           (~290 MB)
          └── :android-debian   (~485 MB)
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

## Corporate Environments

All dock images include `dock-bootstrap` for corporate CA certificate
detection. Add it to your CI `before_script`:

```yaml
default:
  before_script:
    - dock-bootstrap
    - . /etc/dock/ca.env 2>/dev/null || true
```

`dock-bootstrap` auto-detects PEM certificates from environment
variables, files in `/etc/dock/ca.d/`, and GitLab's
`CI_SERVER_TLS_CA_FILE`, then imports them into the system trust
store. On Kubernetes runners where `/etc/ssl/certs/` is read-only,
it builds a private bundle and writes `/etc/dock/ca.env` — source
it to redirect all TLS tools to the new bundle.

Images are published to both GHCR (`ghcr.io/driftsys/dock`) and
Docker Hub (`docker.io/driftsys/dock`). Use whichever your network
allows, or mirror to your internal registry.

See [docs/extending.md](docs/extending.md#corporate-environments)
for full documentation.

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
