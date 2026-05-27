# syntax=docker/dockerfile:1

# Stage 1: grab the Deno binary from the official Alpine image (musl-compatible)
ARG DENO_VERSION=2.8.1
FROM denoland/deno:alpine-${DENO_VERSION} AS deno-bin

# Stage 2: build the dock-deno image
# hadolint ignore=DL3006
FROM dock-core

ARG VERSION=dev
ARG DENO_VERSION=2.8.1
# Copy Deno binary and its bundled glibc runtime from the official Alpine image.
# Since Deno 2.8.x the official Alpine image places glibc in /usr/local/lib/glibc/
# and patches the binary's RPATH with patchelf. The dynamic linker lives at
# /lib/ld-linux-* with a /lib64/ symlink for the amd64 ELF interpreter path.
COPY --from=deno-bin /usr/local/lib/ /usr/local/lib/
COPY --from=deno-bin /lib/ld-linux-* /lib/
# On amd64 the ELF interpreter is /lib64/ld-linux-x86-64.so.2
RUN mkdir -p /lib64 && \
    ln -sf /usr/local/lib/glibc/ld-linux-* /lib64/ 2>/dev/null || \
    ln -sf /lib/ld-linux-* /lib64/ 2>/dev/null || true
COPY --from=deno-bin /bin/deno /usr/local/bin/deno
ENV LD_LIBRARY_PATH=/usr/local/lib/glibc
RUN deno --version

# Point Deno at the system CA bundle for corporate CA support.
ENV DENO_CERT=/etc/ssl/certs/ca-certificates.crt

# Install npx shim — delegates `npx <pkg> [args...]` to `deno run -A npm:<pkg> [args...]`
COPY scripts/npx.sh /usr/local/bin/npx

# Generate manifest
COPY scripts/manifest.sh /usr/local/bin/manifest.sh
RUN manifest.sh deno "${VERSION}"
