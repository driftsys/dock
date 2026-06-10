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

Each image publishes up to three tags:

| Tag             | Variant             | libc  | Use when                                                                        |
| --------------- | ------------------- | ----- | ------------------------------------------------------------------------------- |
| `:image-alpine` | Alpine              | musl  | smallest footprint, where the toolchain supports musl                           |
| `:image-debian` | Debian              | glibc | broadest compatibility (always available)                                       |
| `:image`        | recommended default | —     | points to the variant we recommend per image (see the **Default** column below) |

Some images are **Debian-only** (`python`, `prose`, `polyglot`, `jvm`,
`android`, `android-ndk`) — their toolchains require glibc, so there is no
`-alpine` tag and the bare `:image` resolves to Debian.

### Available images

Sizes are compressed (download) size, amd64.

| Image          | From          | `:image` → | Alpine  | Debian  | Contents                                                     |
| -------------- | ------------- | ---------- | ------- | ------- | ------------------------------------------------------------ |
| `:core`        | `alpine:3.21` | **alpine** | ~30 MB  | ~76 MB  | Shell, Git, curl, jq, yq, gpg, …                             |
| `:rust`        | `:core`       | **debian** | ~557 MB | ~551 MB | Rust stable, cargo, clippy, rustfmt, cargo-audit, cargo-deny |
| `:deno`        | `:core`       | **alpine** | ~78 MB  | ~121 MB | Deno, npx shim, npm shim                                     |
| `:node`        | `:core`       | **alpine** | ~54 MB  | ~135 MB | Node.js LTS, npm                                             |
| `:lint`        | `:deno`       | **alpine** | ~94 MB  | ~138 MB | dprint, shellcheck, editorconfig-checker, git-std (amd64)    |
| `:pages`       | `:core`       | **alpine** | ~77 MB  | ~134 MB | mdbook, typst, tera-cli, lychee, brotli (amd64)              |
| `:python`      | `:core`       | **debian** | —       | ~104 MB | Python 3, pip, ruff                                          |
| `:prose`       | `:core`       | **debian** | —       | ~106 MB | vale, typos, harper-cli, Vale style packs                    |
| `:polyglot`    | `:rust`       | **debian** | —       | ~625 MB | Rust + Deno + Python 3                                       |
| `:jvm`         | `:core`       | **debian** | —       | ~218 MB | JDK 17 headless                                              |
| `:android`     | `:jvm`        | **debian** | —       | ~489 MB | Android SDK (pin: `:android-36-debian`)                      |
| `:android-ndk` | `:android`    | **debian** | —       | ~1.7 GB | NDK + Rust + cargo-ndk (pin: `:android-ndk-27-debian`)       |

The **`:image` →** column is which variant the bare `:image` tag resolves to.
`python`, `prose`, `polyglot`, and the JVM/Android images are Debian-only (no
`-alpine` tag). See [Choosing a variant](#choosing-a-variant).

## Inheritance Tree

### Alpine

```
alpine:3.21
  └── :core          (~30 MB)
      ├── :rust      (~557 MB)
      ├── :deno      (~78 MB)
      │   └── :lint  (~94 MB)
      ├── :node      (~54 MB)
      └── :pages     (~77 MB)
```

### Debian

```
debian:bookworm-slim
  └── :core-debian              (~76 MB)
      ├── :rust-debian          (~551 MB)
      │   └── :polyglot-debian  (~625 MB)
      ├── :deno-debian          (~121 MB)
      │   └── :lint-debian      (~138 MB)
      ├── :node-debian          (~135 MB)
      ├── :python-debian        (~104 MB)
      ├── :pages-debian         (~134 MB)
      ├── :prose-debian         (~106 MB)
      └── :jvm-debian           (~218 MB)
          └── :android-debian   (~489 MB)
              └── :android-ndk-debian (~1.7 GB)
```

## Choosing a variant

Default to **`:image`** — it points to the variant we recommend. Override only
when you have a specific reason:

- **Alpine (`-alpine`)** — smallest footprint; the default for `core`, `deno`,
  `node`, `lint`, and `pages`. Pick `:rust-alpine` when you want static musl
  binaries.
- **Debian (`-debian`)** — broadest compatibility; the default for `rust` (the
  gnu tier-1 target), and the only option for `python`, `prose`, `polyglot`,
  and the JVM/Android images.

Rule of thumb: **Alpine for size, Debian when you need glibc** — Python wheels
(numpy/pandas), glibc-only tools (vale), or native addons without musl builds.

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
| coreutils               | coreutils                                  |
| envsubst                | gettext / gettext-base                     |
| dotenv                  | shell script (both)                        |
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

Each image publishes:

- `:{image}-alpine` / `:{image}-debian` — the explicit variants, plus their
  versioned forms `:{image}-{variant}-{version}`.
- `:{image}` — the recommended default variant, plus `:{image}-{version}`.

`{version}` is the unprefixed semantic release (e.g. `0.2.7`); the unversioned
tags float to the latest release.

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
