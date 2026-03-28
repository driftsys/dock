# syntax=docker/dockerfile:1
# hadolint ignore=DL3006
FROM dock-rust

ARG VERSION=dev
# Deno release to install — keep in sync with images/deno/Dockerfile
ARG DENO_VERSION=2.3.1

LABEL org.opencontainers.image.source="https://github.com/driftsys/dock"
LABEL org.opencontainers.image.revision=""
LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.created=""

# Add Python 3 and ruff
# hadolint ignore=DL3018,DL3013
RUN apk add --no-cache python3 py3-pip && \
    pip install --no-cache-dir --quiet --break-system-packages ruff

# Install Deno via official static binary (GitHub releases)
RUN ARCH="$(uname -m)" && \
    case "$ARCH" in \
      x86_64)  DENO_ARCH="x86_64-unknown-linux-gnu" ;; \
      aarch64) DENO_ARCH="aarch64-unknown-linux-gnu" ;; \
      *)        echo "unsupported arch: $ARCH" && exit 1 ;; \
    esac && \
    curl -sSfL \
      "https://github.com/denoland/deno/releases/download/v${DENO_VERSION}/deno-${DENO_ARCH}.zip" \
      -o /tmp/deno.zip && \
    unzip -q /tmp/deno.zip -d /usr/local/bin && \
    rm /tmp/deno.zip && \
    chmod +x /usr/local/bin/deno && \
    deno --version

# Generate manifest
COPY scripts/manifest.sh /usr/local/bin/manifest.sh
RUN manifest.sh polyglot "${VERSION}"
