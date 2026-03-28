# docker-bake.hcl — Docker Buildx bake file for driftsys/dock
#
# Architectures: linux/amd64 + linux/arm64
# Registry:      ghcr.io/driftsys/dock
# Cache:         registry-based (GHCR)
#
# Usage:
#   docker buildx bake            # build all images locally
#   docker buildx bake core       # build a single target
#   docker buildx bake --push     # build + push to registry

variable "REGISTRY" {
  default = "ghcr.io/driftsys/dock"
}

variable "REGISTRY_DH" {
  default = "docker.io/driftsys/dock"
}

variable "VERSION" {
  default = "dev"
}

variable "PLATFORMS" {
  default = "linux/amd64,linux/arm64"
}

# ---------------------------------------------------------------------------
# Shared defaults
# ---------------------------------------------------------------------------

target "_common" {
  platforms = [PLATFORMS]
  labels = {
    "org.opencontainers.image.source"   = "https://github.com/driftsys/dock"
    "org.opencontainers.image.revision" = ""
    "org.opencontainers.image.version"  = VERSION
    "org.opencontainers.image.created"  = ""
  }
}

target "_cache" {
  cache-from = ["type=registry,ref=${REGISTRY}:cache"]
  cache-to   = ["type=registry,ref=${REGISTRY}:cache,mode=max"]
}

target "lint" {
  inherits   = ["_common", "_cache"]
  context    = "."
  dockerfile = "images/lint/Dockerfile"
  tags = [
    "${REGISTRY}:lint-${VERSION}", "${REGISTRY}:lint",
    "${REGISTRY_DH}:lint-${VERSION}", "${REGISTRY_DH}:lint",
  ]
  contexts  = { dock-core = "target:core" }
  platforms = ["linux/amd64"]
}

# ---------------------------------------------------------------------------
# Alpine images
# ---------------------------------------------------------------------------

target "core" {
  inherits   = ["_common", "_cache"]
  context    = "."
  dockerfile = "images/core/Dockerfile"
  tags = [
    "${REGISTRY}:core-${VERSION}", "${REGISTRY}:core",
    "${REGISTRY_DH}:core-${VERSION}", "${REGISTRY_DH}:core",
  ]
}

target "rust" {
  inherits   = ["_common", "_cache"]
  context    = "."
  dockerfile = "images/rust/Dockerfile"
  tags = [
    "${REGISTRY}:rust-${VERSION}", "${REGISTRY}:rust",
    "${REGISTRY_DH}:rust-${VERSION}", "${REGISTRY_DH}:rust",
  ]
  contexts = { dock-core = "target:core" }
}

target "deno" {
  inherits   = ["_common", "_cache"]
  context    = "."
  dockerfile = "images/deno/Dockerfile"
  tags = [
    "${REGISTRY}:deno-${VERSION}", "${REGISTRY}:deno",
    "${REGISTRY_DH}:deno-${VERSION}", "${REGISTRY_DH}:deno",
  ]
  contexts = { dock-core = "target:core" }
}

target "node" {
  inherits   = ["_common", "_cache"]
  context    = "."
  dockerfile = "images/node/Dockerfile"
  tags = [
    "${REGISTRY}:node-${VERSION}", "${REGISTRY}:node",
    "${REGISTRY_DH}:node-${VERSION}", "${REGISTRY_DH}:node",
  ]
  contexts = { dock-core = "target:core" }
}

target "python" {
  inherits   = ["_common", "_cache"]
  context    = "."
  dockerfile = "images/python/Dockerfile"
  tags = [
    "${REGISTRY}:python-${VERSION}", "${REGISTRY}:python",
    "${REGISTRY_DH}:python-${VERSION}", "${REGISTRY_DH}:python",
  ]
  contexts = { dock-core = "target:core" }
}

target "polyglot" {
  inherits   = ["_common", "_cache"]
  context    = "."
  dockerfile = "images/polyglot/Dockerfile"
  tags = [
    "${REGISTRY}:polyglot-${VERSION}", "${REGISTRY}:polyglot",
    "${REGISTRY_DH}:polyglot-${VERSION}", "${REGISTRY_DH}:polyglot",
  ]
  contexts = { dock-rust = "target:rust" }
}

# ---------------------------------------------------------------------------
# Debian images
# ---------------------------------------------------------------------------

target "core-debian" {
  inherits   = ["_common", "_cache"]
  context    = "."
  dockerfile = "images/core/Dockerfile.debian"
  tags = [
    "${REGISTRY}:core-debian-${VERSION}", "${REGISTRY}:core-debian",
    "${REGISTRY_DH}:core-debian-${VERSION}", "${REGISTRY_DH}:core-debian",
  ]
}

target "rust-debian" {
  inherits   = ["_common", "_cache"]
  context    = "."
  dockerfile = "images/rust/Dockerfile.debian"
  tags = [
    "${REGISTRY}:rust-debian-${VERSION}", "${REGISTRY}:rust-debian",
    "${REGISTRY_DH}:rust-debian-${VERSION}", "${REGISTRY_DH}:rust-debian",
  ]
  contexts = { dock-core = "target:core-debian" }
}

target "deno-debian" {
  inherits   = ["_common", "_cache"]
  context    = "."
  dockerfile = "images/deno/Dockerfile.debian"
  tags = [
    "${REGISTRY}:deno-debian-${VERSION}", "${REGISTRY}:deno-debian",
    "${REGISTRY_DH}:deno-debian-${VERSION}", "${REGISTRY_DH}:deno-debian",
  ]
  contexts = { dock-core = "target:core-debian" }
}

target "node-debian" {
  inherits   = ["_common", "_cache"]
  context    = "."
  dockerfile = "images/node/Dockerfile.debian"
  tags = [
    "${REGISTRY}:node-debian-${VERSION}", "${REGISTRY}:node-debian",
    "${REGISTRY_DH}:node-debian-${VERSION}", "${REGISTRY_DH}:node-debian",
  ]
  contexts = { dock-core = "target:core-debian" }
}

target "python-debian" {
  inherits   = ["_common", "_cache"]
  context    = "."
  dockerfile = "images/python/Dockerfile.debian"
  tags = [
    "${REGISTRY}:python-debian-${VERSION}", "${REGISTRY}:python-debian",
    "${REGISTRY_DH}:python-debian-${VERSION}", "${REGISTRY_DH}:python-debian",
  ]
  contexts = { dock-core = "target:core-debian" }
}

target "polyglot-debian" {
  inherits   = ["_common", "_cache"]
  context    = "."
  dockerfile = "images/polyglot/Dockerfile.debian"
  tags = [
    "${REGISTRY}:polyglot-debian-${VERSION}", "${REGISTRY}:polyglot-debian",
    "${REGISTRY_DH}:polyglot-debian-${VERSION}", "${REGISTRY_DH}:polyglot-debian",
  ]
  contexts = { dock-rust = "target:rust-debian" }
}

# ---------------------------------------------------------------------------
# Groups
# ---------------------------------------------------------------------------

group "alpine" {
  targets = ["core", "rust", "deno", "node", "python", "polyglot", "lint"]
}

group "debian" {
  targets = [
    "core-debian",
    "rust-debian",
    "deno-debian",
    "node-debian",
    "python-debian",
    "polyglot-debian",
  ]
}

group "default" {
  targets = ["alpine", "debian"]
}
