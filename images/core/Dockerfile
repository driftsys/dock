# syntax=docker/dockerfile:1
FROM alpine:3.21

ARG VERSION=dev

LABEL org.opencontainers.image.source="https://github.com/driftsys/dock"
LABEL org.opencontainers.image.revision=""
LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.created=""

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

# Copy manifest helper and generate /etc/dock/manifest.json
COPY scripts/manifest.sh /usr/local/bin/manifest.sh
RUN manifest.sh core "${VERSION}"
