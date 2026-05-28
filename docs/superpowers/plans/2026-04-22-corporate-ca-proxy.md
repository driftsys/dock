# Corporate CA & Extension-Friendly Core — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `:core` (and all child images) corporate-environment
friendly. `dock-bootstrap` in a CI `before_script` auto-detects CA
certificates from environment variables and files, imports them into
the system trust store, and every language tool picks them up
automatically via pre-set ENV vars.

**Architecture:** Two layers of change: (1) `dock-bootstrap` script
installed in `:core` that auto-detects PEM certs from env vars,
files in `/etc/dock/ca.d/`, and `CI_SERVER_TLS_CA_FILE`, then runs
`update-ca-certificates`; (2) ENV declarations in each image's
Dockerfile pointing language tools at the system CA bundle. No new
image variants. No runtime entrypoint.

**Tech Stack:** Dockerfile, POSIX shell, bash_unit, hadolint,
shellcheck, Docker BuildKit (docker-bake.hcl).

**Design decisions:**

- **`dock-bootstrap` replaces `dock-add-ca`** from the original spec.
  Key improvement: auto-detects PEM-encoded certificates in
  environment variables (e.g. `ALLIANCE_ROOT_CA_G2`, or any var
  containing `-----BEGIN CERTIFICATE-----`), not just files.
  Validated on Renault's corporate GitLab — 3 CA env vars detected
  and imported in <1 second, fixing Artifactory TLS.
- **Proxy ARGs dropped.** Docker/BuildKit has predefined build args
  for `HTTP_PROXY`, `HTTPS_PROXY`, `NO_PROXY`. They are available in
  every `RUN` without any `ARG` declaration. Proxy is
  documentation-only.
- **Registry config out of scope.** Org-specific (Artifactory URLs,
  auth tokens). Stays in org CI templates. Dock handles trust, org
  handles config.
- **Java keystore dropped.** No dock image ships a JDK. Dead code.
  Add when a `:java` image exists.
- **Shebang: `#!/bin/sh`.** POSIX-compatible, no bashisms. Works on
  Alpine (`ash`) and Debian (`dash`). Documented exception to
  AGENTS.md `#!/usr/bin/env bash` rule.
- **`:lint` image** inherits from `:core`, needs no changes.

---

## File map

| Action | File                                | Responsibility                                               |
| ------ | ----------------------------------- | ------------------------------------------------------------ |
| Create | `scripts/dock-bootstrap.sh`         | PEM env var detection + file import + update-ca-certificates |
| Modify | `images/core/Dockerfile`            | Add CA-bundle ENVs, COPY dock-bootstrap, mkdir ca.d          |
| Modify | `images/core/Dockerfile.debian`     | Same as above (Debian paths identical)                       |
| Modify | `images/rust/Dockerfile`            | Add `CARGO_HTTP_CAINFO` ENV                                  |
| Modify | `images/rust/Dockerfile.debian`     | Add `CARGO_HTTP_CAINFO` ENV                                  |
| Modify | `images/node/Dockerfile`            | Add `NODE_EXTRA_CA_CERTS` ENV                                |
| Modify | `images/node/Dockerfile.debian`     | Add `NODE_EXTRA_CA_CERTS` ENV                                |
| Modify | `images/python/Dockerfile`          | Add `PIP_CERT` ENV                                           |
| Modify | `images/python/Dockerfile.debian`   | Add `PIP_CERT` ENV                                           |
| Modify | `images/deno/Dockerfile`            | Add `DENO_CERT` ENV                                          |
| Modify | `images/deno/Dockerfile.debian`     | Add `DENO_CERT` ENV                                          |
| Modify | `images/polyglot/Dockerfile`        | Add `DENO_CERT` + `PIP_CERT` ENVs                            |
| Modify | `images/polyglot/Dockerfile.debian` | Add `DENO_CERT` + `PIP_CERT` ENVs                            |
| Create | `tests/fixtures/ca/test-ca.crt`     | Pre-generated self-signed cert for testing                   |
| Modify | `tests/test_core.sh`                | Presence + sanity tests for dock-bootstrap                   |
| Modify | `tests/test_rust.sh`                | CA ENV assertion                                             |
| Modify | `tests/test_node.sh`                | CA ENV assertion                                             |
| Modify | `tests/test_python.sh`              | CA ENV assertion                                             |
| Modify | `tests/test_deno.sh`                | CA ENV assertion                                             |
| Modify | `tests/test_polyglot.sh`            | CA ENV assertions                                            |
| Modify | `docs/extending.md`                 | Corporate environments section                               |
| Modify | `README.md`                         | Short corporate extension blurb                              |
| Modify | `CHANGELOG.md`                      | Release notes                                                |

---

## Task 1: Create `dock-bootstrap` script

**Files:**

- Create: `scripts/dock-bootstrap.sh`

- [ ] **Step 1: Write `scripts/dock-bootstrap.sh`**

```sh
#!/bin/sh
# dock-bootstrap — prepare a dock container for the corporate environment.
#
# Detects CA certificates from three sources and imports them into the
# system trust store so all tools (curl, git, cargo, npm, pip, deno, …)
# trust internal TLS endpoints.
#
# Sources (checked in order):
#   1. Environment variables containing PEM-encoded certificates
#   2. .crt/.pem files in a drop directory (default: /etc/dock/ca.d)
#   3. CI_SERVER_TLS_CA_FILE (GitLab runner-provided CA file)
#
# Usage:
#   dock-bootstrap              # scan env + /etc/dock/ca.d
#   dock-bootstrap /path/to/dir # scan env + custom directory
#   DOCK_SKIP_CA=1 dock-bootstrap  # skip CA detection entirely
#
# Shebang: #!/bin/sh (not bash) — intentionally POSIX-compatible so it
# works in downstream images that may not install bash.
set -eu

CERT_DIR="${1:-/etc/dock/ca.d}"
DEST="/usr/local/share/ca-certificates"
COUNT=0

# -------------------------------------------------------------------------
# 0. Early exit
# -------------------------------------------------------------------------
if [ "${DOCK_SKIP_CA:-0}" = "1" ]; then
  echo "dock-bootstrap: DOCK_SKIP_CA=1, skipping" >&2
  exit 0
fi

# -------------------------------------------------------------------------
# 1. Scan environment variables for PEM-encoded certificates
# -------------------------------------------------------------------------
env_import() {
  env | while IFS='=' read -r name rest; do
    # Skip variables that are unlikely to contain certs
    case "$name" in
      DOCKER_AUTH_CONFIG|GITLAB_FEATURES|CI_*_TOKEN|*PASSWORD*|*SECRET*) continue ;;
    esac
    val=$(printenv "$name" 2>/dev/null) || continue
    case "$val" in
      *"-----BEGIN CERTIFICATE-----"*)
        # Extract each PEM cert block (a variable may contain multiple)
        echo "$val" | awk '
          /-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/ {
            print
            if (/-----END CERTIFICATE-----/) {
              printf "\n"
            }
          }
        ' | csplit -sz -f "$DEST/env-${name}-" -b '%02d.crt' - \
              '/-----BEGIN CERTIFICATE-----/' '{*}' 2>/dev/null || true
        # Count how many were written
        for f in "$DEST/env-${name}-"*.crt 2>/dev/null; do
          [ -f "$f" ] && COUNT=$((COUNT + 1))
        done
        ;;
    esac
  done
}

env_import

# -------------------------------------------------------------------------
# 2. Import .crt/.pem files from the drop directory
# -------------------------------------------------------------------------
if [ -d "$CERT_DIR" ]; then
  for cert in "$CERT_DIR"/*.crt "$CERT_DIR"/*.pem; do
    [ -f "$cert" ] || continue
    base=$(basename "$cert")
    case "$base" in
      *.crt) cp -f "$cert" "$DEST/$base" ;;
      *.pem) cp -f "$cert" "$DEST/${base%.pem}.crt" ;;
    esac
    COUNT=$((COUNT + 1))
  done
fi

# -------------------------------------------------------------------------
# 3. Import CI_SERVER_TLS_CA_FILE (GitLab-specific)
# -------------------------------------------------------------------------
if [ -n "${CI_SERVER_TLS_CA_FILE:-}" ] && [ -f "$CI_SERVER_TLS_CA_FILE" ]; then
  cp -f "$CI_SERVER_TLS_CA_FILE" "$DEST/ci-server-tls-ca.crt"
  COUNT=$((COUNT + 1))
fi

# -------------------------------------------------------------------------
# 4. Update the system trust store
# -------------------------------------------------------------------------
if [ "$COUNT" -gt 0 ]; then
  update-ca-certificates 2>/dev/null
  echo "dock-bootstrap: imported $COUNT certificate source(s) into trust store"
else
  echo "dock-bootstrap: no certificates found, trust store unchanged"
fi
```

- [ ] **Step 2: Run shellcheck on the script**

```bash
shellcheck scripts/dock-bootstrap.sh
```

Expected: 0 warnings. Note: shellcheck may flag the `#!/bin/sh`
shebang if it detects bash-isms — verify the script is pure POSIX.

- [ ] **Step 3: Commit**

```bash
git add scripts/dock-bootstrap.sh
git commit -m "feat(core): add dock-bootstrap script for corporate CA detection"
```

---

## Task 2: Wire CA-bundle ENVs and install `dock-bootstrap` in `:core`

**Files:**

- Modify: `images/core/Dockerfile`
- Modify: `images/core/Dockerfile.debian`

- [ ] **Step 1: Edit `images/core/Dockerfile` (Alpine)**

After the `apk add` RUN block (line 28) and before the manifest
COPY (line 31), add:

```dockerfile
# Point common tools at the system CA bundle so custom CAs added via
# dock-bootstrap are trusted automatically.
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
    SSL_CERT_DIR=/etc/ssl/certs \
    REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt \
    GIT_SSL_CAINFO=/etc/ssl/certs/ca-certificates.crt \
    CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt

# Install dock-bootstrap helper and create the CA drop-directory.
COPY scripts/dock-bootstrap.sh /usr/local/bin/dock-bootstrap
RUN chmod 0755 /usr/local/bin/dock-bootstrap && mkdir -p /etc/dock/ca.d
```

The full file should read:

```dockerfile
# syntax=docker/dockerfile:1
FROM alpine:3.21

ARG VERSION=dev
# Install all core tools in a single layer.
# DL3018: CI toolbox images are rebuilt on each release; reproducibility is
# pinned at the OS level (alpine:3.21), not per-package.
# hadolint ignore=DL3018
RUN apk add --no-cache \
    bash \
    ca-certificates \
    coreutils \
    curl \
    diffutils \
    dotenv \
    findutils \
    gettext \
    git \
    git-lfs \
    gnupg \
    jq \
    openssh-client \
    patch \
    tree \
    tzdata \
    unzip \
    yq-go \
    zip

# Point common tools at the system CA bundle so custom CAs added via
# dock-bootstrap are trusted automatically.
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
    SSL_CERT_DIR=/etc/ssl/certs \
    REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt \
    GIT_SSL_CAINFO=/etc/ssl/certs/ca-certificates.crt \
    CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt

# Install dock-bootstrap helper and create the CA drop-directory.
COPY scripts/dock-bootstrap.sh /usr/local/bin/dock-bootstrap
RUN chmod 0755 /usr/local/bin/dock-bootstrap && mkdir -p /etc/dock/ca.d

# Copy manifest helper and generate /etc/dock/manifest.json
COPY scripts/manifest.sh /usr/local/bin/manifest.sh
RUN manifest.sh core "${VERSION}"
```

- [ ] **Step 2: Edit `images/core/Dockerfile.debian`**

After the dotenv COPY+RUN block (line 42) and before the manifest
COPY (line 45), add the same ENV block and COPY+RUN:

```dockerfile
# Point common tools at the system CA bundle so custom CAs added via
# dock-bootstrap are trusted automatically.
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
    SSL_CERT_DIR=/etc/ssl/certs \
    REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt \
    GIT_SSL_CAINFO=/etc/ssl/certs/ca-certificates.crt \
    CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt

# Install dock-bootstrap helper and create the CA drop-directory.
COPY scripts/dock-bootstrap.sh /usr/local/bin/dock-bootstrap
RUN chmod 0755 /usr/local/bin/dock-bootstrap && mkdir -p /etc/dock/ca.d
```

The full file should read:

```dockerfile
# syntax=docker/dockerfile:1
FROM debian:bookworm-slim

ARG VERSION=dev
# yq release to install (mikefarah/yq — not in Debian bookworm repos)
ARG YQ_VERSION=4.45.1
# Install all core tools available in Debian bookworm
# DL3008: version pinning is at the OS level (debian:bookworm-slim base)
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    coreutils \
    curl \
    diffutils \
    findutils \
    gettext-base \
    git \
    git-lfs \
    gnupg \
    jq \
    openssh-client \
    patch \
    tree \
    tzdata \
    unzip \
    zip \
 && rm -rf /var/lib/apt/lists/*

# Install yq (mikefarah/yq) via official static binary
RUN ARCH="$(dpkg --print-architecture)" && \
    curl -sSfL \
      "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_${ARCH}" \
      -o /usr/local/bin/yq && \
    chmod +x /usr/local/bin/yq && \
    yq --version

# Install dotenv CLI — provides `dotenv run -- <cmd>` for CI pipelines.
# python-dotenv CLI is not packaged as a standalone binary for Debian;
# this minimal shell implementation covers the common CI usage pattern.
COPY scripts/dotenv.sh /usr/local/bin/dotenv
RUN chmod +x /usr/local/bin/dotenv

# Point common tools at the system CA bundle so custom CAs added via
# dock-bootstrap are trusted automatically.
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
    SSL_CERT_DIR=/etc/ssl/certs \
    REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt \
    GIT_SSL_CAINFO=/etc/ssl/certs/ca-certificates.crt \
    CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt

# Install dock-bootstrap helper and create the CA drop-directory.
COPY scripts/dock-bootstrap.sh /usr/local/bin/dock-bootstrap
RUN chmod 0755 /usr/local/bin/dock-bootstrap && mkdir -p /etc/dock/ca.d

# Copy manifest helper and generate /etc/dock/manifest.json
COPY scripts/manifest.sh /usr/local/bin/manifest.sh
RUN manifest.sh core "${VERSION}"
```

- [ ] **Step 3: Run hadolint on both Dockerfiles**

```bash
hadolint images/core/Dockerfile images/core/Dockerfile.debian
```

Expected: 0 warnings.

- [ ] **Step 4: Build `:core` and `:core-debian` locally**

```bash
docker buildx bake core core-debian
```

Expected: both build successfully.

- [ ] **Step 5: Verify ENVs and dock-bootstrap are present**

```bash
docker run --rm ghcr.io/driftsys/dock:core sh -c \
  'echo "$SSL_CERT_FILE" && command -v dock-bootstrap && ls -d /etc/dock/ca.d'
```

Expected output:

```
/etc/ssl/certs/ca-certificates.crt
/usr/local/bin/dock-bootstrap
/etc/dock/ca.d
```

Run the same for `:core-debian`.

- [ ] **Step 6: Commit**

```bash
git add images/core/Dockerfile images/core/Dockerfile.debian
git commit -m "feat(core): pre-wire CA bundle ENVs and install dock-bootstrap"
```

---

## Task 3: Add CA-bundle ENVs to language images

**Files:**

- Modify: `images/rust/Dockerfile`
- Modify: `images/rust/Dockerfile.debian`
- Modify: `images/node/Dockerfile`
- Modify: `images/node/Dockerfile.debian`
- Modify: `images/python/Dockerfile`
- Modify: `images/python/Dockerfile.debian`
- Modify: `images/deno/Dockerfile`
- Modify: `images/deno/Dockerfile.debian`
- Modify: `images/polyglot/Dockerfile`
- Modify: `images/polyglot/Dockerfile.debian`

Each language image gets one `ENV` line for its tool-specific CA
variable. These go **after** the tool installation and **before** the
manifest block. The core ENVs (`SSL_CERT_FILE`, etc.) are already
inherited from `:core`.

- [ ] **Step 1: Edit `images/rust/Dockerfile`**

After the `cargo install` line (line 26), before the manifest
comment, add:

```dockerfile
# Point Cargo at the system CA bundle for corporate CA support.
ENV CARGO_HTTP_CAINFO=/etc/ssl/certs/ca-certificates.crt
```

Full file:

```dockerfile
# syntax=docker/dockerfile:1
# hadolint ignore=DL3006
FROM dock-core

ARG VERSION=dev
# Install C/C++ toolchain and development libraries
# DL3018: version pinning is at the OS level (inherited alpine:3.21 base)
# hadolint ignore=DL3018
RUN apk add --no-cache \
    gcc \
    g++ \
    musl-dev \
    pkgconf \
    openssl-dev

# Install Rust via rustup (stable toolchain with clippy + rustfmt)
ENV CARGO_HOME=/usr/local/cargo \
    RUSTUP_HOME=/usr/local/rustup \
    PATH=/usr/local/cargo/bin:$PATH
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -sSf https://sh.rustup.rs \
    | sh -s -- -y --no-modify-path --default-toolchain stable \
        --component clippy --component rustfmt

# Install cargo-audit and cargo-deny
RUN cargo install cargo-audit cargo-deny --locked

# Point Cargo at the system CA bundle for corporate CA support.
ENV CARGO_HTTP_CAINFO=/etc/ssl/certs/ca-certificates.crt

# Generate manifest
COPY scripts/manifest.sh /usr/local/bin/manifest.sh
RUN manifest.sh rust "${VERSION}"
```

- [ ] **Step 2: Edit `images/rust/Dockerfile.debian`**

Same placement — after `cargo install`, before manifest:

```dockerfile
# Point Cargo at the system CA bundle for corporate CA support.
ENV CARGO_HTTP_CAINFO=/etc/ssl/certs/ca-certificates.crt
```

Full file:

```dockerfile
# syntax=docker/dockerfile:1
# hadolint ignore=DL3006
FROM dock-core

ARG VERSION=dev
# Install C/C++ toolchain and development libraries
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    g++ \
    libc-dev \
    pkg-config \
    libssl-dev \
 && rm -rf /var/lib/apt/lists/*

# Install Rust via rustup (stable toolchain with clippy + rustfmt)
ENV CARGO_HOME=/usr/local/cargo \
    RUSTUP_HOME=/usr/local/rustup \
    PATH=/usr/local/cargo/bin:$PATH
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -sSf https://sh.rustup.rs \
    | sh -s -- -y --no-modify-path --default-toolchain stable \
        --component clippy --component rustfmt

# Install cargo-audit and cargo-deny
RUN cargo install cargo-audit cargo-deny --locked

# Point Cargo at the system CA bundle for corporate CA support.
ENV CARGO_HTTP_CAINFO=/etc/ssl/certs/ca-certificates.crt

# Generate manifest
COPY scripts/manifest.sh /usr/local/bin/manifest.sh
RUN manifest.sh rust "${VERSION}"
```

- [ ] **Step 3: Edit `images/node/Dockerfile`**

After the `apk add` RUN (line 8), before manifest:

```dockerfile
# Point Node.js at the system CA bundle for corporate CA support.
ENV NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt
```

Full file:

```dockerfile
# syntax=docker/dockerfile:1
# hadolint ignore=DL3006
FROM dock-core

ARG VERSION=dev
# Install Node.js LTS and npm
# hadolint ignore=DL3018
RUN apk add --no-cache nodejs npm

# Point Node.js at the system CA bundle for corporate CA support.
ENV NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt

# Generate manifest
COPY scripts/manifest.sh /usr/local/bin/manifest.sh
RUN manifest.sh node "${VERSION}"
```

- [ ] **Step 4: Edit `images/node/Dockerfile.debian`**

After the `apt-get install` RUN, before manifest:

```dockerfile
# Point Node.js at the system CA bundle for corporate CA support.
ENV NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt
```

Full file:

```dockerfile
# syntax=docker/dockerfile:1
# hadolint ignore=DL3006
FROM dock-core

ARG VERSION=dev
# Install Node.js LTS and npm
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
    nodejs \
    npm \
 && rm -rf /var/lib/apt/lists/*

# Point Node.js at the system CA bundle for corporate CA support.
ENV NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt

# Generate manifest
COPY scripts/manifest.sh /usr/local/bin/manifest.sh
RUN manifest.sh node "${VERSION}"
```

- [ ] **Step 5: Edit `images/python/Dockerfile`**

After the `apk add` + `pip install` RUN, before manifest:

```dockerfile
# Point pip at the system CA bundle for corporate CA support.
ENV PIP_CERT=/etc/ssl/certs/ca-certificates.crt
```

Full file:

```dockerfile
# syntax=docker/dockerfile:1
# hadolint ignore=DL3006
FROM dock-core

ARG VERSION=dev
# Install Python 3 and ruff
# hadolint ignore=DL3018,DL3013
RUN apk add --no-cache python3 py3-pip && \
    pip install --no-cache-dir --quiet --break-system-packages ruff

# Point pip at the system CA bundle for corporate CA support.
ENV PIP_CERT=/etc/ssl/certs/ca-certificates.crt

# Generate manifest
COPY scripts/manifest.sh /usr/local/bin/manifest.sh
RUN manifest.sh python "${VERSION}"
```

- [ ] **Step 6: Edit `images/python/Dockerfile.debian`**

After the `apt-get` + `pip install` RUN, before manifest:

```dockerfile
# Point pip at the system CA bundle for corporate CA support.
ENV PIP_CERT=/etc/ssl/certs/ca-certificates.crt
```

Full file:

```dockerfile
# syntax=docker/dockerfile:1
# hadolint ignore=DL3006
FROM dock-core

ARG VERSION=dev
# Install Python 3, pip, and ruff
# hadolint ignore=DL3008,DL3013
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
 && rm -rf /var/lib/apt/lists/* \
 && pip install --no-cache-dir --quiet --break-system-packages ruff

# Point pip at the system CA bundle for corporate CA support.
ENV PIP_CERT=/etc/ssl/certs/ca-certificates.crt

# Generate manifest
COPY scripts/manifest.sh /usr/local/bin/manifest.sh
RUN manifest.sh python "${VERSION}"
```

- [ ] **Step 7: Edit `images/deno/Dockerfile`**

After the `ENV LD_LIBRARY_PATH` and `deno --version` RUN (line 25),
before manifest:

```dockerfile
# Point Deno at the system CA bundle for corporate CA support.
ENV DENO_CERT=/etc/ssl/certs/ca-certificates.crt
```

Full file:

```dockerfile
# syntax=docker/dockerfile:1

# Stage 1: grab the Deno binary from the official Alpine image (musl-compatible)
ARG DENO_VERSION=2.3.1
FROM denoland/deno:alpine-${DENO_VERSION} AS deno-bin

# Stage 2: build the dock-deno image
# hadolint ignore=DL3006
FROM dock-core

ARG VERSION=dev
ARG DENO_VERSION=2.3.1
# Copy Deno binary and its bundled glibc runtime from the official Alpine image.
# Deno links against glibc; the official Alpine image bundles glibc in /usr/local/lib.
# The dynamic linker symlink lives at /lib/ld-linux-* (arm64) or /lib64/ (amd64).
COPY --from=deno-bin /usr/local/lib/ /usr/local/lib/
COPY --from=deno-bin /lib/ld-linux-* /lib/
# On amd64 the loader is referenced via /lib64/ld-linux-x86-64.so.2
RUN mkdir -p /lib64 && \
    for f in /usr/local/lib/ld-linux-*.so.*; do \
      [ -e "$f" ] && ln -sf "$f" "/lib64/$(basename "$f")"; \
    done
COPY --from=deno-bin /bin/deno /usr/local/bin/deno
ENV LD_LIBRARY_PATH=/usr/local/lib
RUN deno --version

# Point Deno at the system CA bundle for corporate CA support.
ENV DENO_CERT=/etc/ssl/certs/ca-certificates.crt

# Generate manifest
COPY scripts/manifest.sh /usr/local/bin/manifest.sh
RUN manifest.sh deno "${VERSION}"
```

- [ ] **Step 8: Edit `images/deno/Dockerfile.debian`**

After the deno install RUN, before manifest:

```dockerfile
# Point Deno at the system CA bundle for corporate CA support.
ENV DENO_CERT=/etc/ssl/certs/ca-certificates.crt
```

Full file:

```dockerfile
# syntax=docker/dockerfile:1
# hadolint ignore=DL3006
FROM dock-core

ARG VERSION=dev
# Deno release to install — keep in sync with images/deno/Dockerfile
ARG DENO_VERSION=2.3.1
# Install Deno via official static binary (GitHub releases)
RUN DPKG_ARCH="$(dpkg --print-architecture)" && \
    case "$DPKG_ARCH" in \
      amd64)  DENO_ARCH="x86_64-unknown-linux-gnu" ;; \
      arm64)  DENO_ARCH="aarch64-unknown-linux-gnu" ;; \
      *)      echo "unsupported arch: $DPKG_ARCH" && exit 1 ;; \
    esac && \
    curl -sSfL \
      "https://github.com/denoland/deno/releases/download/v${DENO_VERSION}/deno-${DENO_ARCH}.zip" \
      -o /tmp/deno.zip && \
    unzip -q /tmp/deno.zip -d /usr/local/bin && \
    rm /tmp/deno.zip && \
    chmod +x /usr/local/bin/deno && \
    deno --version

# Point Deno at the system CA bundle for corporate CA support.
ENV DENO_CERT=/etc/ssl/certs/ca-certificates.crt

# Generate manifest
COPY scripts/manifest.sh /usr/local/bin/manifest.sh
RUN manifest.sh deno "${VERSION}"
```

- [ ] **Step 9: Edit `images/polyglot/Dockerfile`**

Polyglot inherits from `:rust` (which inherits `:core`), so it gets
`SSL_CERT_FILE` etc. from core and `CARGO_HTTP_CAINFO` from rust.
It bundles Deno and Python, so add `DENO_CERT` and `PIP_CERT`.

After the `deno --version` RUN (line 32), before manifest:

```dockerfile
# Point Deno and pip at the system CA bundle for corporate CA support.
# CARGO_HTTP_CAINFO is inherited from :rust; core ENVs from :core.
ENV DENO_CERT=/etc/ssl/certs/ca-certificates.crt \
    PIP_CERT=/etc/ssl/certs/ca-certificates.crt
```

Full file:

```dockerfile
# syntax=docker/dockerfile:1

# Stage 1: grab the Deno binary from the official Alpine image (musl-compatible)
ARG DENO_VERSION=2.3.1
FROM denoland/deno:alpine-${DENO_VERSION} AS deno-bin

# Stage 2: build the dock-polyglot image
# hadolint ignore=DL3006
FROM dock-rust

ARG VERSION=dev
ARG DENO_VERSION=2.3.1
# Add Python 3 and ruff
# hadolint ignore=DL3018,DL3013
RUN apk add --no-cache python3 py3-pip && \
    pip install --no-cache-dir --quiet --break-system-packages ruff

# Copy Deno binary and its bundled glibc runtime from the official Alpine image.
# Deno links against glibc; the official Alpine image bundles glibc in /usr/local/lib.
# Copy glibc compat libs for Deno, but remove libgcc_s.so.1 which conflicts
# with the musl-linked copy used by Rust (causes relocation errors).
COPY --from=deno-bin /usr/local/lib/ /usr/local/lib/
RUN rm -f /usr/local/lib/libgcc_s.so.1
COPY --from=deno-bin /lib/ld-linux-* /lib/
# On amd64 the loader is referenced via /lib64/ld-linux-x86-64.so.2
RUN mkdir -p /lib64 && \
    for f in /usr/local/lib/ld-linux-*.so.*; do \
      [ -e "$f" ] && ln -sf "$f" "/lib64/$(basename "$f")"; \
    done
COPY --from=deno-bin /bin/deno /usr/local/bin/deno
ENV LD_LIBRARY_PATH=/usr/local/lib
RUN deno --version

# Point Deno and pip at the system CA bundle for corporate CA support.
# CARGO_HTTP_CAINFO is inherited from :rust; core ENVs from :core.
ENV DENO_CERT=/etc/ssl/certs/ca-certificates.crt \
    PIP_CERT=/etc/ssl/certs/ca-certificates.crt

# Generate manifest
COPY scripts/manifest.sh /usr/local/bin/manifest.sh
RUN manifest.sh polyglot "${VERSION}"
```

- [ ] **Step 10: Edit `images/polyglot/Dockerfile.debian`**

After the deno install RUN, before manifest:

```dockerfile
# Point Deno and pip at the system CA bundle for corporate CA support.
# CARGO_HTTP_CAINFO is inherited from :rust; core ENVs from :core.
ENV DENO_CERT=/etc/ssl/certs/ca-certificates.crt \
    PIP_CERT=/etc/ssl/certs/ca-certificates.crt
```

Full file:

```dockerfile
# syntax=docker/dockerfile:1
# hadolint ignore=DL3006
FROM dock-rust

ARG VERSION=dev
# Deno release to install — keep in sync with images/deno/Dockerfile.debian
ARG DENO_VERSION=2.3.1
# Add Python 3, pip, and ruff
# hadolint ignore=DL3008,DL3013
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
 && rm -rf /var/lib/apt/lists/* \
 && pip install --no-cache-dir --quiet --break-system-packages ruff

# Install Deno via official static binary (GitHub releases)
RUN DPKG_ARCH="$(dpkg --print-architecture)" && \
    case "$DPKG_ARCH" in \
      amd64)  DENO_ARCH="x86_64-unknown-linux-gnu" ;; \
      arm64)  DENO_ARCH="aarch64-unknown-linux-gnu" ;; \
      *)      echo "unsupported arch: $DPKG_ARCH" && exit 1 ;; \
    esac && \
    curl -sSfL \
      "https://github.com/denoland/deno/releases/download/v${DENO_VERSION}/deno-${DENO_ARCH}.zip" \
      -o /tmp/deno.zip && \
    unzip -q /tmp/deno.zip -d /usr/local/bin && \
    rm /tmp/deno.zip && \
    chmod +x /usr/local/bin/deno && \
    deno --version

# Point Deno and pip at the system CA bundle for corporate CA support.
# CARGO_HTTP_CAINFO is inherited from :rust; core ENVs from :core.
ENV DENO_CERT=/etc/ssl/certs/ca-certificates.crt \
    PIP_CERT=/etc/ssl/certs/ca-certificates.crt

# Generate manifest
COPY scripts/manifest.sh /usr/local/bin/manifest.sh
RUN manifest.sh polyglot "${VERSION}"
```

- [ ] **Step 11: Run hadolint on all modified Dockerfiles**

```bash
find images -name 'Dockerfile*' | xargs hadolint
```

Expected: 0 warnings.

- [ ] **Step 12: Build all images**

```bash
docker buildx bake
```

Expected: all targets build successfully.

- [ ] **Step 13: Commit**

```bash
git add images/
git commit -m "feat: pre-wire CA bundle ENVs for all language images"
```

---

## Task 4: Add tests for `dock-bootstrap`

**Files:**

- Modify: `tests/test_core.sh`
- Create: `tests/fixtures/ca/test-ca.crt`

Tests are added to `test_core.sh` because `dock-bootstrap` is
installed in `:core`. All child image test suites source
`test_core.sh`, so these tests run for every image automatically.

- [ ] **Step 1: Generate the test fixture certificate**

Run on your dev machine (which has openssl):

```bash
mkdir -p tests/fixtures/ca
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout /dev/null \
  -out tests/fixtures/ca/test-ca.crt \
  -days 3650 -subj "/CN=dock-test-ca" 2>/dev/null
```

This creates a long-lived (10 year) self-signed cert for testing.
The private key is intentionally discarded — we only need the cert
for trust-store testing.

- [ ] **Step 2: Verify the fixture was created**

```bash
openssl x509 -in tests/fixtures/ca/test-ca.crt -noout -subject
```

Expected: `subject=CN = dock-test-ca`

- [ ] **Step 3: Add tests to `tests/test_core.sh`**

Append after the existing `test_manifest_has_image` function
(line 73):

```bash
# ---------------------------------------------------------------------------
# Corporate CA support
# ---------------------------------------------------------------------------

test_dock_bootstrap_present() {
  assert "command -v dock-bootstrap"
}

test_ca_drop_dir_exists() {
  assert "[ -d /etc/dock/ca.d ]"
}

test_ssl_cert_file_env() {
  assert_equals "/etc/ssl/certs/ca-certificates.crt" "$SSL_CERT_FILE"
}

test_ssl_cert_dir_env() {
  assert_equals "/etc/ssl/certs" "$SSL_CERT_DIR"
}

test_curl_ca_bundle_env() {
  assert_equals "/etc/ssl/certs/ca-certificates.crt" "$CURL_CA_BUNDLE"
}

test_git_ssl_cainfo_env() {
  assert_equals "/etc/ssl/certs/ca-certificates.crt" "$GIT_SSL_CAINFO"
}

# dock-bootstrap exits 0 with no certs present (empty ca.d, no PEM env vars)
test_dock_bootstrap_noop() {
  assert "dock-bootstrap /etc/dock/ca.d"
}

# dock-bootstrap imports a certificate file from the drop directory.
# Uses a pre-generated test fixture cert to avoid requiring openssl.
test_dock_bootstrap_imports_file() {
  local ca_dir
  ca_dir="$(mktemp -d)"

  cp /fixtures/ca/test-ca.crt "$ca_dir/"

  dock-bootstrap "$ca_dir"

  assert "grep -q 'dock-test-ca' /etc/ssl/certs/ca-certificates.crt" \
    "test cert should appear in system CA bundle after dock-bootstrap"

  rm -rf "$ca_dir"
}

# dock-bootstrap detects PEM certificates in environment variables.
test_dock_bootstrap_imports_env_var() {
  local cert_pem
  cert_pem="$(cat /fixtures/ca/test-ca.crt)"

  # Export a PEM cert as an env var, run dock-bootstrap, check trust store
  DOCK_TEST_CA="$cert_pem" \
    dock-bootstrap /nonexistent 2>/dev/null

  assert "grep -q 'dock-test-ca' /etc/ssl/certs/ca-certificates.crt" \
    "PEM cert from env var should appear in system CA bundle"
}

# dock-bootstrap respects DOCK_SKIP_CA
test_dock_bootstrap_skip() {
  local output
  output="$(DOCK_SKIP_CA=1 dock-bootstrap 2>&1)"
  assert_equals "dock-bootstrap: DOCK_SKIP_CA=1, skipping" "$output"
}
```

- [ ] **Step 4: Verify fixtures are mounted**

The existing `run.sh` mounts `${FIXTURES_DIR}:/fixtures:ro`. The
file `tests/fixtures/ca/test-ca.crt` will appear at
`/fixtures/ca/test-ca.crt` inside the container. No change needed
to `run.sh`.

- [ ] **Step 5: Run shellcheck on test_core.sh**

```bash
shellcheck tests/test_core.sh
```

Expected: 0 warnings.

- [ ] **Step 6: Run the core tests locally**

```bash
just test-image core
```

Expected: all tests pass, including the new `test_dock_bootstrap_*`
tests.

- [ ] **Step 7: Commit**

```bash
git add tests/test_core.sh tests/fixtures/ca/
git commit -m "test(core): add dock-bootstrap presence and import tests"
```

---

## Task 5: Add language-specific ENV tests to child image test suites

**Files:**

- Modify: `tests/test_rust.sh`
- Modify: `tests/test_node.sh`
- Modify: `tests/test_python.sh`
- Modify: `tests/test_deno.sh`
- Modify: `tests/test_polyglot.sh`

Each child image test gets one assertion verifying its
tool-specific CA ENV is set. The core ENVs are already tested
via inheritance from `test_core.sh`.

- [ ] **Step 1: Edit `tests/test_rust.sh`**

Insert between the Presence tests section and the Sanity tests
section (between lines 18 and 19 of the current file):

```bash
# ---------------------------------------------------------------------------
# CA bundle tests
# ---------------------------------------------------------------------------

test_cargo_cainfo_env() {
  assert_equals "/etc/ssl/certs/ca-certificates.crt" "$CARGO_HTTP_CAINFO"
}
```

- [ ] **Step 2: Edit `tests/test_node.sh`**

Insert between presence and sanity sections (after line 13):

```bash
# ---------------------------------------------------------------------------
# CA bundle tests
# ---------------------------------------------------------------------------

test_node_extra_ca_certs_env() {
  assert_equals "/etc/ssl/certs/ca-certificates.crt" "$NODE_EXTRA_CA_CERTS"
}
```

- [ ] **Step 3: Edit `tests/test_python.sh`**

Insert between presence and sanity sections (after line 14):

```bash
# ---------------------------------------------------------------------------
# CA bundle tests
# ---------------------------------------------------------------------------

test_pip_cert_env() {
  assert_equals "/etc/ssl/certs/ca-certificates.crt" "$PIP_CERT"
}
```

- [ ] **Step 4: Edit `tests/test_deno.sh`**

Insert between presence and sanity sections (after line 12):

```bash
# ---------------------------------------------------------------------------
# CA bundle tests
# ---------------------------------------------------------------------------

test_deno_cert_env() {
  assert_equals "/etc/ssl/certs/ca-certificates.crt" "$DENO_CERT"
}
```

- [ ] **Step 5: Edit `tests/test_polyglot.sh`**

Polyglot inherits the Cargo test from `test_rust.sh`. Add Deno and
pip tests. Insert after the Python presence section (after line 20):

```bash
# ---------------------------------------------------------------------------
# CA bundle tests (Deno + pip; Cargo inherited from test_rust.sh)
# ---------------------------------------------------------------------------

test_polyglot_deno_cert_env() {
  assert_equals "/etc/ssl/certs/ca-certificates.crt" "$DENO_CERT"
}

test_polyglot_pip_cert_env() {
  assert_equals "/etc/ssl/certs/ca-certificates.crt" "$PIP_CERT"
}
```

- [ ] **Step 6: Run shellcheck on all test files**

```bash
find tests -name '*.sh' | xargs shellcheck
```

Expected: 0 warnings.

- [ ] **Step 7: Run the full test suite**

```bash
just test
```

Expected: all tests pass for all images (Alpine + Debian variants).

- [ ] **Step 8: Commit**

```bash
git add tests/
git commit -m "test: add CA bundle ENV assertions for all language images"
```

---

## Task 6: Update documentation

**Files:**

- Modify: `docs/extending.md`
- Modify: `README.md`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Add corporate environments section to
      `docs/extending.md`**

Append after the existing "Multi-stage builds" section (end of file):

````markdown
## Corporate environments

### CA certificates with `dock-bootstrap`

If your CI runners provide corporate CA certificates (as environment
variables, files, or via GitLab's `CI_SERVER_TLS_CA_FILE`),
`dock-bootstrap` detects and imports them into the system trust store
automatically:

```yaml
# GitLab CI — add to your pipeline
default:
  before_script:
    - dock-bootstrap
```

That's it. `dock-bootstrap` scans three sources:

1. **Environment variables** — any env var containing a PEM
   certificate (`-----BEGIN CERTIFICATE-----`) is detected and
   imported. This works with GitLab group/instance CI/CD variables
   that contain CA certificates.
2. **Drop directory** — `.crt` and `.pem` files in `/etc/dock/ca.d/`
   (or a custom path passed as `$1`).
3. **`CI_SERVER_TLS_CA_FILE`** — the GitLab runner-provided CA file,
   if present.

All dock images pre-set `SSL_CERT_FILE`, `CURL_CA_BUNDLE`,
`GIT_SSL_CAINFO`, and language-specific variables
(`CARGO_HTTP_CAINFO`, `NODE_EXTRA_CA_CERTS`, `DENO_CERT`, `PIP_CERT`)
to point at `/etc/ssl/certs/ca-certificates.crt` — the file
`update-ca-certificates` populates. Every tool picks up custom CAs
without further configuration.

To skip CA detection (e.g. in jobs that don't need it):

```yaml
variables:
  DOCK_SKIP_CA: "1"
```

### Fetching CA certificates at CI build time

If you need CAs at Docker **build** time (not just runtime), fetch
them from a central store in your CI pipeline rather than committing
them to git:

```yaml
build:
  before_script:
    - curl -sSf https://artifactory.corp/certs/ca-bundle.tar.gz
        -o ca-bundle.tar.gz
    - mkdir -p corp-certs && tar -xzf ca-bundle.tar.gz -C corp-certs
  script:
    - docker build -t my-ci-image .
```

```dockerfile
FROM ghcr.io/driftsys/dock:rust
COPY corp-certs/ /etc/dock/ca.d/
RUN dock-bootstrap
```

### Build-time HTTP proxy

Docker's built-in predefined build args handle proxy pass-through —
no Dockerfile changes needed:

```bash
docker build \
  --build-arg HTTP_PROXY=http://proxy.corp:3128 \
  --build-arg HTTPS_PROXY=http://proxy.corp:3128 \
  --build-arg NO_PROXY=.corp.internal,10.0.0.0/8 \
  -t my-ci-image .
```

In **GitLab CI**:

```yaml
build:
  variables:
    HTTP_PROXY: http://proxy.corp:3128
    HTTPS_PROXY: http://proxy.corp:3128
    NO_PROXY: .corp.internal
  script:
    - docker build
        --build-arg HTTP_PROXY
        --build-arg HTTPS_PROXY
        --build-arg NO_PROXY
        -t my-ci-image .
```

In **GitHub Actions**:

```yaml
- name: Build
  run: |
    docker build \
      --build-arg HTTP_PROXY=${{ vars.HTTP_PROXY }} \
      --build-arg HTTPS_PROXY=${{ vars.HTTPS_PROXY }} \
      --build-arg NO_PROXY=${{ vars.NO_PROXY }} \
      -t my-ci-image .
```

Note: these affect **build time** only. For runtime proxy, set the
variables via `docker run -e` or your orchestrator's environment
configuration.

### Why no `-corp` variant?

Corporate CAs are per-organisation — baking one into a public image
would be wrong. Instead, dock images are designed to make extension
trivial: run `dock-bootstrap` and your trust store is ready.

### Registry mirrors

Registry configuration is org-specific. Use the standard environment
variables that each tool already respects:

| Tool  | Env var               | Example                                 |
| ----- | --------------------- | --------------------------------------- |
| npm   | `NPM_CONFIG_REGISTRY` | `https://artifactory.corp/npm/`         |
| pip   | `PIP_INDEX_URL`       | `https://artifactory.corp/pypi/simple/` |
| Cargo | (needs config file)   | See below                               |

For Cargo, write `$CARGO_HOME/config.toml` in a setup script:

```toml
[source.crates-io]
replace-with = "corp-mirror"

[source.corp-mirror]
registry = "https://artifactory.corp/cargo/"
```

Set these as CI/CD variables at the group or instance level in your
CI platform — no changes to dock images needed.

### Verifying connectivity in CI

Add a connectivity check job to confirm your extended image can
reach public and private registries:

**GitLab CI** (`.gitlab-ci.yml`):

```yaml
verify-connectivity:
  image: your-corp-image:latest
  before_script:
    - dock-bootstrap
  script:
    - "curl -sSf https://registry.npmjs.org/ > /dev/null
        && echo 'npmjs: ok'"
    - "curl -sSf https://crates.io/api/v1/crates?per_page=1
        > /dev/null && echo 'crates.io: ok'"
    - "curl -sSf https://pypi.org/simple/ > /dev/null
        && echo 'pypi: ok'"
    # Internal registries:
    - "curl -sSf https://artifactory.corp/ > /dev/null
        && echo 'artifactory: ok'"
```

If any `curl` call fails, the job fails — catching TLS or proxy
misconfigurations before they break real builds.
````

- [ ] **Step 2: Add corporate extension blurb to `README.md`**

Insert before the `## Tags` section (before line 88), after the
Core Package List table:

````markdown
## Corporate Environments

All dock images include `dock-bootstrap` for corporate CA certificate
detection. Add it to your CI `before_script`:

```yaml
default:
  before_script:
    - dock-bootstrap
```
````

`dock-bootstrap` auto-detects PEM certificates from environment
variables, files in `/etc/dock/ca.d/`, and GitLab's
`CI_SERVER_TLS_CA_FILE`, then imports them into the system trust
store. All language tools are pre-configured to use the system CA
bundle.

See [docs/extending.md](docs/extending.md#corporate-environments)
for full documentation.

````
- [ ] **Step 3: Update `CHANGELOG.md`**

Prepend a new release section before the existing `[0.1.3]` entry:

```markdown
## [Unreleased]

### Added

- `dock-bootstrap` — auto-detects CA certificates from environment
  variables, drop directory (`/etc/dock/ca.d/`), and
  `CI_SERVER_TLS_CA_FILE`; imports into the system trust store
- Pre-configured CA bundle paths for cargo, npm, deno, pip, git,
  curl across all images
- Documentation for corporate environments: CA injection, proxy
  pass-through, registry mirrors, connectivity verification
````

- [ ] **Step 4: Run `dprint check` to verify Markdown formatting**

```bash
dprint check
```

If there are formatting issues, run `dprint fmt` and review.

- [ ] **Step 5: Commit**

```bash
git add docs/extending.md README.md CHANGELOG.md
git commit -m "docs: add corporate environment guide with dock-bootstrap"
```

---

## Task 7: Final verification

- [ ] **Step 1: Run the full lint suite**

```bash
just lint
```

Expected: 0 warnings from hadolint, shellcheck, and dprint.

- [ ] **Step 2: Build all images**

```bash
just build
```

Expected: all images build successfully.

- [ ] **Step 3: Run the full test suite**

```bash
just test
```

Expected: all tests pass for all images (Alpine + Debian variants).

- [ ] **Step 4: Spot-check image size delta**

```bash
docker images --format '{{.Repository}}:{{.Tag}} {{.Size}}' \
  | grep 'driftsys/dock' | sort
```

Expected: `:core` size increase < 1 MB.

- [ ] **Step 5: Verify no behavior change for default users**

```bash
docker run --rm ghcr.io/driftsys/dock:core \
  curl -sSf https://github.com > /dev/null && echo "ok"
```

Expected: `ok` — default trust store is unchanged.

---

## Summary of commits

| # | Message                                                            | Scope                                                          |
| - | ------------------------------------------------------------------ | -------------------------------------------------------------- |
| 1 | `feat(core): add dock-bootstrap script for corporate CA detection` | `scripts/dock-bootstrap.sh`                                    |
| 2 | `feat(core): pre-wire CA bundle ENVs and install dock-bootstrap`   | `images/core/Dockerfile{,.debian}`                             |
| 3 | `feat: pre-wire CA bundle ENVs for all language images`            | `images/{rust,node,python,deno,polyglot}/Dockerfile{,.debian}` |
| 4 | `test(core): add dock-bootstrap presence and import tests`         | `tests/test_core.sh`, `tests/fixtures/ca/`                     |
| 5 | `test: add CA bundle ENV assertions for all language images`       | `tests/test_{rust,node,python,deno,polyglot}.sh`               |
| 6 | `docs: add corporate environment guide with dock-bootstrap`        | `docs/extending.md`, `README.md`, `CHANGELOG.md`               |

Note: AGENTS.md says "One commit per PR." If this lands as a single
PR, squash these into one commit with message:
`feat(core): add dock-bootstrap for corporate CA auto-detection and trust store setup`
