# syntax=docker/dockerfile:1
#
# dock:lint — code and documentation linting toolbox (Alpine).
#
# Inherits from dock:core (Alpine CI foundation).
# Adds: hadolint, shellcheck, shfmt, editorconfig-checker, git-std, prim, gitleaks.
#
# Platform: linux/amd64 only (git-std and prim lack arm64 Linux builds).

# hadolint ignore=DL3006
FROM dock-core

ARG VERSION=dev

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

# ---------------------------------------------------------------------------
# Tool versions (pinned for reproducibility)
# ---------------------------------------------------------------------------
ARG GIT_STD_VERSION=0.11.19
ARG GITLEAKS_VERSION=8.30.1
ARG HADOLINT_VERSION=2.15.1
ARG PRIM_VERSION=0.9.1

# ---------------------------------------------------------------------------
# System packages: shellcheck + editorconfig-checker
# ---------------------------------------------------------------------------
# hadolint ignore=DL3018
RUN apk add --no-cache shellcheck shfmt editorconfig-checker && \
    ln -s /usr/bin/ec /usr/bin/editorconfig-checker

# hadolint — Dockerfile linter (static binary, amd64-only lint image)
RUN curl -sSfL \
      "https://github.com/hadolint/hadolint/releases/download/v${HADOLINT_VERSION}/hadolint-linux-x86_64" \
      -o /usr/local/bin/hadolint && \
    chmod +x /usr/local/bin/hadolint && \
    hadolint --version

# gitleaks — secrets scanner (static binary, amd64-only lint image)
RUN curl -sSfL \
      "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz" \
      -o /tmp/gitleaks.tar.gz && \
    tar -xzf /tmp/gitleaks.tar.gz -C /usr/local/bin gitleaks && \
    rm /tmp/gitleaks.tar.gz && \
    chmod +x /usr/local/bin/gitleaks && \
    gitleaks version

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
# prim — repository connective-tissue formatter and linter
# ---------------------------------------------------------------------------
RUN curl -sSfL \
      "https://github.com/driftsys/prim/releases/download/v${PRIM_VERSION}/prim-x86_64-unknown-linux-musl.tar.gz" \
      -o /tmp/prim.tar.gz && \
    tar -xzf /tmp/prim.tar.gz -C /usr/local/bin && \
    rm /tmp/prim.tar.gz && \
    chmod +x /usr/local/bin/prim && \
    prim --version

# ---------------------------------------------------------------------------
# Generate manifest
# ---------------------------------------------------------------------------
COPY scripts/manifest.sh /usr/local/bin/manifest.sh
RUN manifest.sh lint "${VERSION}" \
    "gitleaks:gitleaks version" \
    "hadolint:hadolint --version" \
    "shellcheck:shellcheck --version" \
    "shfmt:shfmt --version" \
    "editorconfig-checker:editorconfig-checker --version" \
    "git-std:git-std --version" \
    "prim:prim --version"
