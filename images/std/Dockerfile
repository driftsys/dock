# syntax=docker/dockerfile:1
#
# dock:std — git-std toolbox (Alpine).
#
# Inherits from dock:core (shell foundation + git).
# Adds: git-std — conventional commits, changelog, versioning, git hooks.
#
# Platform: linux/amd64 only (git-std lacks arm64 Linux builds).

# hadolint ignore=DL3006
FROM dock-core

ARG VERSION=dev

# ---------------------------------------------------------------------------
# Tool versions (pinned for reproducibility)
# ---------------------------------------------------------------------------
ARG GIT_STD_VERSION=0.11.12

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
RUN manifest.sh std "${VERSION}"
