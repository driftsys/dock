# Getting Started

## Pull an image

Images are available from both GHCR and Docker Hub:

```bash
# From GitHub Container Registry (default)
docker pull ghcr.io/driftsys/dock:core

# From Docker Hub
docker pull driftsys/dock:core
```

Both registries publish the same images with identical digests.

## Run interactively

```bash
docker run --rm -it ghcr.io/driftsys/dock:core bash
```

## Use in GitHub Actions

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    container: ghcr.io/driftsys/dock:rust
    steps:
      - uses: actions/checkout@v4
      - run: cargo build --release
      - run: cargo test
```

## Use in GitLab CI

```yaml
build:
  image: ghcr.io/driftsys/dock:rust
  script:
    - cargo build --release
    - cargo test
```

## Choose a variant

Every image ships in two variants:

| Tag             | Base                   | libc  | Best for                    |
| --------------- | ---------------------- | ----- | --------------------------- |
| `:image`        | `alpine:3.21`          | musl  | Smallest footprint, default |
| `:image-debian` | `debian:bookworm-slim` | glibc | Broader compatibility       |

Use the Debian variant when your tools require glibc (e.g. pre-built
binaries that don't support musl).

Some images are **Debian-only** because their upstream toolchain
requires glibc: `:jvm-debian` (JDK 17) and `:android-debian`
(Android SDK). These have no Alpine variant.

## Pin a version

Floating tags (`:core`, `:rust`, ...) always point to the latest release.
For reproducible builds, pin to a version tag:

```yaml
container: ghcr.io/driftsys/dock:rust-0.1.0
```

## Inspect the manifest

Each image records installed tool versions in `/etc/dock/manifest.json`:

```bash
docker run --rm ghcr.io/driftsys/dock:rust \
  jq . /etc/dock/manifest.json
```

```json
{
  "image": "rust",
  "version": "0.1.0",
  "tools": {
    "rustc": "1.83.0",
    "cargo": "1.83.0",
    "clippy": "0.1.83",
    "rustfmt": "1.8.0"
  }
}
```

## Next steps

- [Extending images](extending.md) — add packages on top of dock images
- [Versioning strategy](versioning.md) — tags, pinning, rebuild policy
- Browse the [Image Reference](images/core.md) for per-image details
