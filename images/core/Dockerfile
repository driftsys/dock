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
