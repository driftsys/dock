# syntax=docker/dockerfile:1
#
# dock:lint — code and documentation linting toolbox (Alpine).
#
# Inherits from dock:deno (Alpine + Deno runtime + npx/npm shims).
# Adds: shellcheck, editorconfig-checker, git-std, dprint.
# npx gives access to markdownlint-cli2, prettier, and any npm linter.
#
# Platform: linux/amd64 only (git-std lacks arm64 Linux builds).

# hadolint ignore=DL3006
FROM dock-deno

ARG VERSION=dev

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

# ---------------------------------------------------------------------------
# Tool versions (pinned for reproducibility)
# ---------------------------------------------------------------------------
ARG GIT_STD_VERSION=0.11.12
ARG DPRINT_VERSION=0.54.0

# ---------------------------------------------------------------------------
# System packages: shellcheck + editorconfig-checker
# ---------------------------------------------------------------------------
# hadolint ignore=DL3018
RUN apk add --no-cache shellcheck editorconfig-checker && \
    ln -s /usr/bin/ec /usr/bin/editorconfig-checker

# ---------------------------------------------------------------------------
# dprint — fast code formatter (Rust binary, covers md/json/toml/yaml)
# ---------------------------------------------------------------------------
RUN curl -sSfL \
      "https://github.com/dprint/dprint/releases/download/${DPRINT_VERSION}/dprint-x86_64-unknown-linux-musl.zip" \
      -o /tmp/dprint.zip && \
    unzip -o /tmp/dprint.zip -d /usr/local/bin && \
    rm /tmp/dprint.zip && \
    chmod +x /usr/local/bin/dprint && \
    dprint --version

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
# Generate manifest
# ---------------------------------------------------------------------------
COPY scripts/manifest.sh /usr/local/bin/manifest.sh
RUN manifest.sh lint "${VERSION}"
