# syntax=docker/dockerfile:1
# hadolint ignore=DL3006
FROM dock-core

ARG VERSION=dev

LABEL org.opencontainers.image.source="https://github.com/driftsys/dock"
LABEL org.opencontainers.image.revision=""
LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.created=""

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
# DL4006: pipefail is set via ENV — not applicable in this RUN form
# hadolint ignore=DL4006
RUN curl -sSf https://sh.rustup.rs \
    | sh -s -- -y --no-modify-path --default-toolchain stable \
        --component clippy rustfmt

# Install cargo-audit and cargo-deny
RUN cargo install cargo-audit cargo-deny --locked

# Generate manifest
COPY scripts/manifest.sh /usr/local/bin/manifest.sh
RUN manifest.sh rust "${VERSION}"
