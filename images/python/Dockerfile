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
