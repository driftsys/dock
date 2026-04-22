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
