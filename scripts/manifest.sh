#!/usr/bin/env bash
# scripts/manifest.sh — generate /etc/dock/manifest.json inside an image layer.
#
# Usage (from a Dockerfile RUN instruction):
#   RUN /scripts/manifest.sh <image> <version>
#
# Writes: /etc/dock/manifest.json
#
# The file records the image name and the resolved versions of all
# key tools present in PATH at build time.
set -euo pipefail

IMAGE="${1:?image name required (e.g. core)}"
VERSION="${2:?image version required (e.g. 1.0.0)}"

resolve_version() {
  local cmd="$1"
  shift
  if command -v "$cmd" >/dev/null 2>&1; then
    "$cmd" "$@" 2>&1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1
  else
    echo "n/a"
  fi
}

mkdir -p /etc/dock

cat > /etc/dock/manifest.json <<EOF
{
  "image": "$IMAGE",
  "version": "$VERSION",
  "built_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "tools": {
    "git": "$(resolve_version git --version)",
    "git-lfs": "$(resolve_version git-lfs version)",
    "bash": "$(resolve_version bash --version)",
    "curl": "$(resolve_version curl --version)",
    "jq": "$(resolve_version jq --version)",
    "yq": "$(resolve_version yq --version)",
    "gpg": "$(resolve_version gpg --version)",
    "ssh": "$(resolve_version ssh -V)"
  }
}
EOF
