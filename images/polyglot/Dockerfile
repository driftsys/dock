# syntax=docker/dockerfile:1

# Stage 1: grab the Deno binary from the official Alpine image (musl-compatible)
ARG DENO_VERSION=2.3.1
FROM denoland/deno:alpine-${DENO_VERSION} AS deno-bin

# Stage 2: build the dock-polyglot image
# hadolint ignore=DL3006
FROM dock-rust

ARG VERSION=dev
ARG DENO_VERSION=2.3.1
# Add Python 3 and ruff
# hadolint ignore=DL3018,DL3013
RUN apk add --no-cache python3 py3-pip && \
    pip install --no-cache-dir --quiet --break-system-packages ruff

# Copy Deno binary and its bundled glibc runtime from the official Alpine image.
# Deno links against glibc; the official Alpine image bundles glibc in /usr/local/lib.
# Copy glibc compat libs for Deno, but remove libgcc_s.so.1 which conflicts
# with the musl-linked copy used by Rust (causes relocation errors).
COPY --from=deno-bin /usr/local/lib/ /usr/local/lib/
RUN rm -f /usr/local/lib/libgcc_s.so.1
COPY --from=deno-bin /lib/ld-linux-* /lib/
# On amd64 the loader is referenced via /lib64/ld-linux-x86-64.so.2
RUN mkdir -p /lib64 && \
    for f in /usr/local/lib/ld-linux-*.so.*; do \
      [ -e "$f" ] && ln -sf "$f" "/lib64/$(basename "$f")"; \
    done
COPY --from=deno-bin /bin/deno /usr/local/bin/deno
ENV LD_LIBRARY_PATH=/usr/local/lib
RUN deno --version

# Point Deno and pip at the system CA bundle for corporate CA support.
# CARGO_HTTP_CAINFO is inherited from :rust; core ENVs from :core.
ENV DENO_CERT=/etc/ssl/certs/ca-certificates.crt \
    PIP_CERT=/etc/ssl/certs/ca-certificates.crt

# Generate manifest
COPY scripts/manifest.sh /usr/local/bin/manifest.sh
RUN manifest.sh polyglot "${VERSION}"
