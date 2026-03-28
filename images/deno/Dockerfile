# syntax=docker/dockerfile:1

# Stage 1: grab the Deno binary from the official Alpine image (musl-compatible)
ARG DENO_VERSION=2.3.1
FROM denoland/deno:alpine-${DENO_VERSION} AS deno-bin

# Stage 2: build the dock-deno image
# hadolint ignore=DL3006
FROM dock-core

ARG VERSION=dev
ARG DENO_VERSION=2.3.1
# Copy Deno binary and its bundled glibc runtime from the official Alpine image.
# Deno links against glibc; the official Alpine image bundles glibc in /usr/local/lib.
# The dynamic linker symlink lives at /lib/ld-linux-* (arm64) or /lib64/ (amd64).
COPY --from=deno-bin /usr/local/lib/ /usr/local/lib/
COPY --from=deno-bin /lib/ld-linux-* /lib/
# On amd64 the loader is referenced via /lib64/ld-linux-x86-64.so.2
RUN mkdir -p /lib64 && \
    for f in /usr/local/lib/ld-linux-*.so.*; do \
      [ -e "$f" ] && ln -sf "$f" "/lib64/$(basename "$f")"; \
    done
COPY --from=deno-bin /bin/deno /usr/local/bin/deno
ENV LD_LIBRARY_PATH=/usr/local/lib
RUN deno --version

# Generate manifest
COPY scripts/manifest.sh /usr/local/bin/manifest.sh
RUN manifest.sh deno "${VERSION}"
