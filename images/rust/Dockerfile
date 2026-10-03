# syntax=docker/dockerfile:1
# hadolint ignore=DL3006
FROM dock-core

ARG VERSION=dev
ARG CLIPPY_SARIF_VERSION=0.8.0
ARG SARIF_FMT_VERSION=0.8.0
# Install C/C++ toolchain and development libraries
# DL3018: version pinning is at the OS level (inherited alpine:3.24 base)
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

# Build native SARIF tools separately to preserve the audit/deny cache layer.
RUN cargo install clippy-sarif --version "${CLIPPY_SARIF_VERSION}" --locked && \
    cargo install sarif-fmt --version "${SARIF_FMT_VERSION}" --locked

# Point Cargo at the system CA bundle for corporate CA support.
ENV CARGO_HTTP_CAINFO=/etc/ssl/certs/ca-certificates.crt

# Generate manifest
COPY scripts/manifest.sh /usr/local/bin/manifest.sh
RUN manifest.sh rust "${VERSION}" \
    "rustc:rustc --version" \
    "cargo:cargo --version" \
    "cargo-audit:cargo-audit --version" \
    "cargo-deny:cargo-deny --version" \
    "clippy:cargo clippy --version" \
    "clippy-sarif:clippy-sarif --version" \
    "sarif-fmt:sarif-fmt --version" \
    "rustfmt:rustfmt --version"
