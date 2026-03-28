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

variable "DENO_VERSION" {
  default = "2.3.1"
}

# Appended to every tag during per-arch CI builds (e.g. "-amd64", "-arm64").
# Left empty for local builds and for the final multi-arch manifest.
variable "PLATFORM_SUFFIX" {
  default = ""
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

target "_cache-alpine" {
  cache-from = ["type=registry,ref=${REGISTRY}:cache-alpine"]
  cache-to   = ["type=registry,ref=${REGISTRY}:cache-alpine,mode=max"]
}

target "_cache-debian" {
  cache-from = ["type=registry,ref=${REGISTRY}:cache-debian"]
  cache-to   = ["type=registry,ref=${REGISTRY}:cache-debian,mode=max"]
}

target "lint" {
  inherits   = ["_common", "_cache-alpine"]
  context    = "."
  dockerfile = "images/lint/Dockerfile"
  tags = [
    "${REGISTRY}:lint-${VERSION}${PLATFORM_SUFFIX}", "${REGISTRY}:lint${PLATFORM_SUFFIX}",
    "${REGISTRY_DH}:lint-${VERSION}${PLATFORM_SUFFIX}", "${REGISTRY_DH}:lint${PLATFORM_SUFFIX}",
  ]
  contexts  = { dock-core = "target:core" }
  platforms = ["linux/amd64"]
}

# ---------------------------------------------------------------------------
# Alpine images
# ---------------------------------------------------------------------------

target "core" {
  inherits   = ["_common", "_cache-alpine"]
  context    = "."
  dockerfile = "images/core/Dockerfile"
  tags = [
    "${REGISTRY}:core-${VERSION}${PLATFORM_SUFFIX}", "${REGISTRY}:core${PLATFORM_SUFFIX}",
    "${REGISTRY_DH}:core-${VERSION}${PLATFORM_SUFFIX}", "${REGISTRY_DH}:core${PLATFORM_SUFFIX}",
  ]
}

target "rust" {
  inherits   = ["_common", "_cache-alpine"]
  context    = "."
  dockerfile = "images/rust/Dockerfile"
  tags = [
    "${REGISTRY}:rust-${VERSION}${PLATFORM_SUFFIX}", "${REGISTRY}:rust${PLATFORM_SUFFIX}",
    "${REGISTRY_DH}:rust-${VERSION}${PLATFORM_SUFFIX}", "${REGISTRY_DH}:rust${PLATFORM_SUFFIX}",
  ]
  contexts = { dock-core = "target:core" }
}

target "deno" {
  inherits   = ["_common", "_cache-alpine"]
  context    = "."
  dockerfile = "images/deno/Dockerfile"
  args       = { DENO_VERSION = DENO_VERSION }
  tags = [
    "${REGISTRY}:deno-${VERSION}${PLATFORM_SUFFIX}", "${REGISTRY}:deno${PLATFORM_SUFFIX}",
    "${REGISTRY_DH}:deno-${VERSION}${PLATFORM_SUFFIX}", "${REGISTRY_DH}:deno${PLATFORM_SUFFIX}",
  ]
  contexts = { dock-core = "target:core" }
}

target "node" {
  inherits   = ["_common", "_cache-alpine"]
  context    = "."
  dockerfile = "images/node/Dockerfile"
  tags = [
    "${REGISTRY}:node-${VERSION}${PLATFORM_SUFFIX}", "${REGISTRY}:node${PLATFORM_SUFFIX}",
    "${REGISTRY_DH}:node-${VERSION}${PLATFORM_SUFFIX}", "${REGISTRY_DH}:node${PLATFORM_SUFFIX}",
  ]
  contexts = { dock-core = "target:core" }
}

target "python" {
  inherits   = ["_common", "_cache-alpine"]
  context    = "."
  dockerfile = "images/python/Dockerfile"
  tags = [
    "${REGISTRY}:python-${VERSION}${PLATFORM_SUFFIX}", "${REGISTRY}:python${PLATFORM_SUFFIX}",
    "${REGISTRY_DH}:python-${VERSION}${PLATFORM_SUFFIX}", "${REGISTRY_DH}:python${PLATFORM_SUFFIX}",
  ]
  contexts = { dock-core = "target:core" }
}

target "polyglot" {
  inherits   = ["_common", "_cache-alpine"]
  context    = "."
  dockerfile = "images/polyglot/Dockerfile"
  args       = { DENO_VERSION = DENO_VERSION }
  tags = [
    "${REGISTRY}:polyglot-${VERSION}${PLATFORM_SUFFIX}", "${REGISTRY}:polyglot${PLATFORM_SUFFIX}",
    "${REGISTRY_DH}:polyglot-${VERSION}${PLATFORM_SUFFIX}", "${REGISTRY_DH}:polyglot${PLATFORM_SUFFIX}",
  ]
  contexts = { dock-rust = "target:rust" }
}

# ---------------------------------------------------------------------------
# Debian images
# ---------------------------------------------------------------------------

target "core-debian" {
  inherits   = ["_common", "_cache-debian"]
  context    = "."
  dockerfile = "images/core/Dockerfile.debian"
  tags = [
    "${REGISTRY}:core-debian-${VERSION}${PLATFORM_SUFFIX}", "${REGISTRY}:core-debian${PLATFORM_SUFFIX}",
    "${REGISTRY_DH}:core-debian-${VERSION}${PLATFORM_SUFFIX}", "${REGISTRY_DH}:core-debian${PLATFORM_SUFFIX}",
  ]
}

target "rust-debian" {
  inherits   = ["_common", "_cache-debian"]
  context    = "."
  dockerfile = "images/rust/Dockerfile.debian"
  tags = [
    "${REGISTRY}:rust-debian-${VERSION}${PLATFORM_SUFFIX}", "${REGISTRY}:rust-debian${PLATFORM_SUFFIX}",
    "${REGISTRY_DH}:rust-debian-${VERSION}${PLATFORM_SUFFIX}", "${REGISTRY_DH}:rust-debian${PLATFORM_SUFFIX}",
  ]
  contexts = { dock-core = "target:core-debian" }
}

target "deno-debian" {
  inherits   = ["_common", "_cache-debian"]
  context    = "."
  dockerfile = "images/deno/Dockerfile.debian"
  args       = { DENO_VERSION = DENO_VERSION }
  tags = [
    "${REGISTRY}:deno-debian-${VERSION}${PLATFORM_SUFFIX}", "${REGISTRY}:deno-debian${PLATFORM_SUFFIX}",
    "${REGISTRY_DH}:deno-debian-${VERSION}${PLATFORM_SUFFIX}", "${REGISTRY_DH}:deno-debian${PLATFORM_SUFFIX}",
  ]
  contexts = { dock-core = "target:core-debian" }
}

target "node-debian" {
  inherits   = ["_common", "_cache-debian"]
  context    = "."
  dockerfile = "images/node/Dockerfile.debian"
  tags = [
    "${REGISTRY}:node-debian-${VERSION}${PLATFORM_SUFFIX}", "${REGISTRY}:node-debian${PLATFORM_SUFFIX}",
    "${REGISTRY_DH}:node-debian-${VERSION}${PLATFORM_SUFFIX}", "${REGISTRY_DH}:node-debian${PLATFORM_SUFFIX}",
  ]
  contexts = { dock-core = "target:core-debian" }
}

target "python-debian" {
  inherits   = ["_common", "_cache-debian"]
  context    = "."
  dockerfile = "images/python/Dockerfile.debian"
  tags = [
    "${REGISTRY}:python-debian-${VERSION}${PLATFORM_SUFFIX}", "${REGISTRY}:python-debian${PLATFORM_SUFFIX}",
    "${REGISTRY_DH}:python-debian-${VERSION}${PLATFORM_SUFFIX}", "${REGISTRY_DH}:python-debian${PLATFORM_SUFFIX}",
  ]
  contexts = { dock-core = "target:core-debian" }
}

target "polyglot-debian" {
  inherits   = ["_common", "_cache-debian"]
  context    = "."
  dockerfile = "images/polyglot/Dockerfile.debian"
  args       = { DENO_VERSION = DENO_VERSION }
  tags = [
    "${REGISTRY}:polyglot-debian-${VERSION}${PLATFORM_SUFFIX}", "${REGISTRY}:polyglot-debian${PLATFORM_SUFFIX}",
    "${REGISTRY_DH}:polyglot-debian-${VERSION}${PLATFORM_SUFFIX}", "${REGISTRY_DH}:polyglot-debian${PLATFORM_SUFFIX}",
  ]
  contexts = { dock-rust = "target:rust-debian" }
}

# ---------------------------------------------------------------------------
# Groups
# ---------------------------------------------------------------------------

group "alpine" {
  targets = ["core", "rust", "deno", "node", "python", "polyglot", "lint"]
}

# All multi-arch targets (excludes lint which is amd64-only)
group "multiarch" {
  targets = ["core", "rust", "deno", "node", "python", "polyglot"]
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
