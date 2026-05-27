# syntax=docker/dockerfile:1
#
# dock:pages — static site generation and documentation tooling.
#
# Inherits from dock:deno (Alpine + Deno runtime + npx shim).
# Adds: mdbook, typst, tera-cli, git-std, mdbook plugins, brotli, fonts.
#
# Platform: linux/amd64 only (git-std and mdbook-linkcheck lack arm64 Linux builds).

# hadolint ignore=DL3006
FROM dock-deno

ARG VERSION=dev

# Use pipefail so curl failures in pipes are caught.
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

# ---------------------------------------------------------------------------
# Tool versions (pinned for reproducibility)
# ---------------------------------------------------------------------------
ARG MDBOOK_VERSION=0.5.3
ARG TYPST_VERSION=0.14.2
ARG TERA_CLI_VERSION=0.5.0
ARG GIT_STD_VERSION=0.9.0
ARG MDBOOK_ADMONISH_VERSION=1.20.0
ARG MDBOOK_KATEX_VERSION=0.10.0-alpha
ARG MDBOOK_LINKCHECK_VERSION=0.7.7

# ---------------------------------------------------------------------------
# System packages: compression + fonts
# ---------------------------------------------------------------------------
# hadolint ignore=DL3018
RUN apk add --no-cache \
      brotli \
      font-noto \
      xz

# ---------------------------------------------------------------------------
# mdbook — book/site generator
# ---------------------------------------------------------------------------
RUN curl -sSfL \
      "https://github.com/rust-lang/mdBook/releases/download/v${MDBOOK_VERSION}/mdbook-v${MDBOOK_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
      | tar -xz -C /usr/local/bin && \
    chmod +x /usr/local/bin/mdbook && \
    mdbook --version

# ---------------------------------------------------------------------------
# typst — PDF/document compiler
# ---------------------------------------------------------------------------
RUN curl -sSfL \
      "https://github.com/typst/typst/releases/download/v${TYPST_VERSION}/typst-x86_64-unknown-linux-musl.tar.xz" \
      | tar -xJ --strip-components=1 -C /usr/local/bin && \
    chmod +x /usr/local/bin/typst && \
    typst --version

# ---------------------------------------------------------------------------
# tera-cli — Jinja2/Twig-like template engine
# ---------------------------------------------------------------------------
RUN curl -sSfL \
      "https://github.com/chevdor/tera-cli/releases/download/v${TERA_CLI_VERSION}/tera-cli-x86_64-unknown-linux-musl.tar.gz" \
      | tar -xz -C /usr/local/bin && \
    chmod +x /usr/local/bin/tera && \
    tera --version

# ---------------------------------------------------------------------------
# git-std — git commit conventions + hooks
# ---------------------------------------------------------------------------
RUN curl -sSfL \
      "https://github.com/driftsys/git-std/releases/download/v${GIT_STD_VERSION}/git-std-x86_64-unknown-linux-musl.tar.gz" \
      -o /tmp/git-std.tar.gz && \
    tar -xzf /tmp/git-std.tar.gz -C /usr/local/bin && \
    rm /tmp/git-std.tar.gz && \
    chmod +x /usr/local/bin/git-std && \
    git-std --version

# ---------------------------------------------------------------------------
# mdbook-admonish — callout/admonition blocks (note, warning, tip, danger)
# ---------------------------------------------------------------------------
RUN curl -sSfL \
      "https://github.com/tommilligan/mdbook-admonish/releases/download/v${MDBOOK_ADMONISH_VERSION}/mdbook-admonish-v${MDBOOK_ADMONISH_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
      | tar -xz -C /usr/local/bin && \
    chmod +x /usr/local/bin/mdbook-admonish && \
    mdbook-admonish --version

# ---------------------------------------------------------------------------
# mdbook-katex — server-side LaTeX math rendering
# ---------------------------------------------------------------------------
RUN curl -sSfL \
      "https://github.com/lzanini/mdbook-katex/releases/download/${MDBOOK_KATEX_VERSION}-binaries/mdbook-katex-v${MDBOOK_KATEX_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
      | tar -xz -C /usr/local/bin && \
    chmod +x /usr/local/bin/mdbook-katex && \
    mdbook-katex --version

# ---------------------------------------------------------------------------
# mdbook-linkcheck — broken link validation at build time
# NOTE: Only gnu build available; works via glibc compat layer from dock:deno.
# ---------------------------------------------------------------------------
RUN curl -sSfL \
      "https://github.com/Michael-F-Bryan/mdbook-linkcheck/releases/download/v${MDBOOK_LINKCHECK_VERSION}/mdbook-linkcheck.x86_64-unknown-linux-gnu.zip" \
      -o /tmp/mdbook-linkcheck.zip && \
    unzip -o /tmp/mdbook-linkcheck.zip -d /usr/local/bin && \
    rm /tmp/mdbook-linkcheck.zip && \
    chmod +x /usr/local/bin/mdbook-linkcheck && \
    mdbook-linkcheck --version

# ---------------------------------------------------------------------------
# Generate manifest
# ---------------------------------------------------------------------------
COPY scripts/manifest.sh /usr/local/bin/manifest.sh
RUN manifest.sh pages "${VERSION}"
