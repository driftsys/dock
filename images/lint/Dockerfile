# syntax=docker/dockerfile:1
# hadolint ignore=DL3006
FROM dock-core

ARG VERSION=dev
# git-std release to install. Only linux/amd64 available from driftsys/git-std releases.
ARG GIT_STD_VERSION=0.6.0

LABEL org.opencontainers.image.source="https://github.com/driftsys/dock"
LABEL org.opencontainers.image.revision=""
LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.created=""

# Install shellcheck and editorconfig-checker via apk
# hadolint ignore=DL3018
RUN apk add --no-cache shellcheck editorconfig-checker

# Install git-std (linux/amd64 only — no aarch64 Linux binary in releases)
RUN curl -sSfL \
      "https://github.com/driftsys/git-std/releases/download/v${GIT_STD_VERSION}/git-std-x86_64-unknown-linux-musl.tar.gz" \
      -o /tmp/git-std.tar.gz && \
    tar -xzf /tmp/git-std.tar.gz -C /usr/local/bin && \
    rm /tmp/git-std.tar.gz && \
    chmod +x /usr/local/bin/git-std && \
    git-std --version

# Generate manifest
COPY scripts/manifest.sh /usr/local/bin/manifest.sh
RUN manifest.sh lint "${VERSION}"
