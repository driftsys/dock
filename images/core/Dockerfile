# syntax=docker/dockerfile:1
FROM alpine:3.24

ARG VERSION=dev
# Install all core tools in a single layer.
# Alpine 3.24 packages rsync 3.5.0, which cannot read Bash process-substitution
# filters. Use the tagged edge package for rsync; other tools use Alpine 3.24.
# DL3018: CI toolbox images are rebuilt on each release; reproducibility is
# pinned at the OS level (alpine:3.24), not per-package (rsync uses edge).
# hadolint ignore=DL3018
RUN printf '%s\n' '@rsync https://dl-cdn.alpinelinux.org/alpine/edge/main' \
      >> /etc/apk/repositories \
 && apk add --no-cache \
    bash \
    ca-certificates \
    coreutils \
    curl \
    diffutils \
    findutils \
    gettext \
    git \
    git-lfs \
    gnupg \
    jq \
    openssh-client \
    patch \
    ripgrep \
    rsync@rsync \
    tree \
    tzdata \
    unzip \
    yq-go \
    zip

# Install dotenv CLI — provides `dotenv run -- <cmd>` for CI pipelines.
# Uses the shared shell shim (scripts/dotenv.sh) instead of the py3-dotenv
# package, which would pull in the full python3 runtime (~32 MB uncompressed)
# and cascade that weight to every descendant image. Matches Debian core.
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
