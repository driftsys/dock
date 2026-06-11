# syntax=docker/dockerfile:1
#
# dock:lint — code and documentation linting toolbox (Alpine).
#
# Inherits from dock:deno (Alpine + Deno runtime + npx/npm shims).
# Adds: shellcheck, editorconfig-checker, dprint.
# npx gives access to markdownlint-cli2, prettier, and any npm linter.
#
# Platform: linux/amd64 only (dprint is installed as an x86_64 binary).

# hadolint ignore=DL3006
FROM dock-deno

ARG VERSION=dev

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

# ---------------------------------------------------------------------------
# Tool versions (pinned for reproducibility)
# ---------------------------------------------------------------------------
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
# Generate manifest
# ---------------------------------------------------------------------------
COPY scripts/manifest.sh /usr/local/bin/manifest.sh
RUN manifest.sh lint "${VERSION}"
