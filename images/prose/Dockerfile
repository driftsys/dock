# syntax=docker/dockerfile:1
#
# dock:prose — English prose quality toolbox (Alpine).
#
# Inherits from dock:core (Alpine scripting foundation). Every tool is a
# static musl binary, so no glibc runtime is required.
# Adds: typos (typo detection), harper-cli (grammar).
#
# NOTE: vale ships only gnu builds (needs glibc + libstdc++), so it lives in
# the Debian variant only — see dock:prose-debian.
#
# Platform: linux/amd64 + linux/arm64 (both tools ship both arches).

# hadolint ignore=DL3006
FROM dock-core

ARG VERSION=dev

# Use pipefail so curl failures in pipes are caught.
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

# ---------------------------------------------------------------------------
# Tool versions (pinned for reproducibility)
# ---------------------------------------------------------------------------
ARG TYPOS_VERSION=1.46.3
ARG HARPER_VERSION=2.2.1

# ---------------------------------------------------------------------------
# typos — fast typo detector (Rust binary, static musl, multi-arch)
# ---------------------------------------------------------------------------
RUN APK_ARCH="$(apk --print-arch)" && \
    case "$APK_ARCH" in \
      x86_64)  TYPOS_ARCH="x86_64-unknown-linux-musl" ;; \
      aarch64) TYPOS_ARCH="aarch64-unknown-linux-musl" ;; \
      *)       echo "unsupported arch: $APK_ARCH" && exit 1 ;; \
    esac && \
    curl -sSfL \
      "https://github.com/crate-ci/typos/releases/download/v${TYPOS_VERSION}/typos-v${TYPOS_VERSION}-${TYPOS_ARCH}.tar.gz" \
      | tar -xz -C /usr/local/bin ./typos && \
    chmod +x /usr/local/bin/typos && \
    typos --version

# ---------------------------------------------------------------------------
# harper-cli — English grammar checker (Rust binary, static musl, multi-arch)
# ---------------------------------------------------------------------------
RUN APK_ARCH="$(apk --print-arch)" && \
    case "$APK_ARCH" in \
      x86_64)  HARPER_ARCH="x86_64-unknown-linux-musl" ;; \
      aarch64) HARPER_ARCH="aarch64-unknown-linux-musl" ;; \
      *)       echo "unsupported arch: $APK_ARCH" && exit 1 ;; \
    esac && \
    curl -sSfL \
      "https://github.com/Automattic/harper/releases/download/v${HARPER_VERSION}/harper-cli-${HARPER_ARCH}.tar.gz" \
      | tar -xz -C /usr/local/bin && \
    chmod +x /usr/local/bin/harper-cli && \
    harper-cli --version

# ---------------------------------------------------------------------------
# Generate manifest
# ---------------------------------------------------------------------------
COPY scripts/manifest.sh /usr/local/bin/manifest.sh
RUN manifest.sh prose "${VERSION}"
