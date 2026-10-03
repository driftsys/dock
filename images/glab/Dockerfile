# syntax=docker/dockerfile:1
# hadolint ignore=DL3006
FROM dock-deno

ARG VERSION=dev
ARG GLAB_VERSION=1.120.0
ARG SARIF_CONVERTER_VERSION=0.9.4
ARG REVIEWDOG_VERSION=0.21.2

# glab: official static GitLab CLI release.
RUN case "$(uname -m)" in \
      x86_64) arch=amd64 ;; aarch64) arch=arm64 ;; \
      *) echo "unsupported architecture" && exit 1 ;; \
    esac && \
    curl -sSfL "https://gitlab.com/gitlab-org/cli/-/releases/v${GLAB_VERSION}/downloads/glab_${GLAB_VERSION}_linux_${arch}.tar.gz" \
      -o /tmp/glab.tar.gz && \
    tar -xzf /tmp/glab.tar.gz -C /usr/local/bin bin/glab --strip-components=1 && \
    rm /tmp/glab.tar.gz && glab version

# sarif-converter: SARIF to GitLab Code Quality or SAST.
RUN case "$(uname -m)" in \
      x86_64) arch=amd64 ;; aarch64) arch=arm64 ;; \
      *) echo "unsupported architecture" && exit 1 ;; \
    esac && \
    curl -sSfL "https://gitlab.com/ignis-build/sarif-converter/-/releases/v${SARIF_CONVERTER_VERSION}/downloads/bin/sarif-converter-linux-${arch}" \
      -o /usr/local/bin/sarif-converter && \
    chmod +x /usr/local/bin/sarif-converter && sarif-converter --version

# reviewdog: pipe-mode reporting and diff filtering, without producer linters.
RUN case "$(uname -m)" in \
      x86_64) arch=x86_64 ;; aarch64) arch=arm64 ;; \
      *) echo "unsupported architecture" && exit 1 ;; \
    esac && \
    curl -sSfL "https://github.com/reviewdog/reviewdog/releases/download/v${REVIEWDOG_VERSION}/reviewdog_${REVIEWDOG_VERSION}_Linux_${arch}.tar.gz" \
      -o /tmp/reviewdog.tar.gz && \
    tar -xzf /tmp/reviewdog.tar.gz -C /usr/local/bin reviewdog && \
    rm /tmp/reviewdog.tar.gz && reviewdog -version

COPY --chmod=755 scripts/tap2junit.ts /usr/local/bin/tap2junit

COPY scripts/manifest.sh /usr/local/bin/manifest.sh
RUN manifest.sh glab "${VERSION}" \
    "glab:glab version" \
    "sarif-converter:sarif-converter --version" \
    "reviewdog:reviewdog -version" \
    "tap2junit:tap2junit --version"
