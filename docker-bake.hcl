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
  default = "2.8.1"
}

variable "ANDROID_PLATFORM_VERSION" {
  default = "36"
}

variable "ANDROID_NDK_VERSION" {
  default = "27"
}

# Appended to every tag during per-arch CI builds (e.g. "-amd64", "-arm64").
# Left empty for local builds and for the final multi-arch manifest.
variable "PLATFORM_SUFFIX" {
  default = ""
}

# ---------------------------------------------------------------------------
# Tag scheme
# ---------------------------------------------------------------------------
# Every variant publishes an explicit suffixed tag (`:image-alpine`,
# `:image-debian`). The variant we recommend for an image (see README →
# "Choosing a variant") additionally claims the bare `:image` tag by passing
# bare = true. Exactly one variant per image sets bare = true.
function "img_tags" {
  params = [image, variant, bare]
  result = concat(
    [
      "${REGISTRY}:${image}-${variant}-${VERSION}${PLATFORM_SUFFIX}",
      "${REGISTRY}:${image}-${variant}${PLATFORM_SUFFIX}",
      "${REGISTRY_DH}:${image}-${variant}-${VERSION}${PLATFORM_SUFFIX}",
      "${REGISTRY_DH}:${image}-${variant}${PLATFORM_SUFFIX}",
    ],
    bare ? [
      "${REGISTRY}:${image}-${VERSION}${PLATFORM_SUFFIX}",
      "${REGISTRY}:${image}${PLATFORM_SUFFIX}",
      "${REGISTRY_DH}:${image}-${VERSION}${PLATFORM_SUFFIX}",
      "${REGISTRY_DH}:${image}${PLATFORM_SUFFIX}",
    ] : []
  )
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

# ---------------------------------------------------------------------------
# Alpine images
# ---------------------------------------------------------------------------

target "core" {
  inherits   = ["_common", "_cache-alpine"]
  context    = "."
  dockerfile = "images/core/Dockerfile"
  tags       = img_tags("core", "alpine", true)
}

target "rust" {
  inherits   = ["_common", "_cache-alpine"]
  context    = "."
  dockerfile = "images/rust/Dockerfile"
  tags       = img_tags("rust", "alpine", false)
  contexts   = { dock-core = "target:core" }
}

target "deno" {
  inherits   = ["_common", "_cache-alpine"]
  context    = "."
  dockerfile = "images/deno/Dockerfile"
  args       = { DENO_VERSION = DENO_VERSION }
  tags       = img_tags("deno", "alpine", true)
  contexts   = { dock-core = "target:core" }
}

target "node" {
  inherits   = ["_common", "_cache-alpine"]
  context    = "."
  dockerfile = "images/node/Dockerfile"
  tags       = img_tags("node", "alpine", true)
  contexts   = { dock-core = "target:core" }
}

target "lint" {
  inherits   = ["_common", "_cache-alpine"]
  context    = "."
  dockerfile = "images/lint/Dockerfile"
  tags       = img_tags("lint", "alpine", true)
  contexts   = { dock-deno = "target:deno" }
  platforms  = ["linux/amd64"]
}

target "std" {
  inherits   = ["_common", "_cache-alpine"]
  context    = "."
  dockerfile = "images/std/Dockerfile"
  tags       = img_tags("std", "alpine", true)
  contexts   = { dock-core = "target:core" }
  platforms  = ["linux/amd64"]
}

target "pages" {
  inherits   = ["_common", "_cache-alpine"]
  context    = "."
  dockerfile = "images/pages/Dockerfile"
  tags       = img_tags("pages", "alpine", true)
  contexts   = { dock-core = "target:core" }
  platforms  = ["linux/amd64"]
}

# ---------------------------------------------------------------------------
# Debian images
# ---------------------------------------------------------------------------

target "core-debian" {
  inherits   = ["_common", "_cache-debian"]
  context    = "."
  dockerfile = "images/core/Dockerfile.debian"
  tags       = img_tags("core", "debian", false)
}

target "rust-debian" {
  inherits   = ["_common", "_cache-debian"]
  context    = "."
  dockerfile = "images/rust/Dockerfile.debian"
  tags       = img_tags("rust", "debian", true)
  contexts   = { dock-core = "target:core-debian" }
}

target "deno-debian" {
  inherits   = ["_common", "_cache-debian"]
  context    = "."
  dockerfile = "images/deno/Dockerfile.debian"
  args       = { DENO_VERSION = DENO_VERSION }
  tags       = img_tags("deno", "debian", false)
  contexts   = { dock-core = "target:core-debian" }
}

target "node-debian" {
  inherits   = ["_common", "_cache-debian"]
  context    = "."
  dockerfile = "images/node/Dockerfile.debian"
  tags       = img_tags("node", "debian", false)
  contexts   = { dock-core = "target:core-debian" }
}

target "python-debian" {
  inherits   = ["_common", "_cache-debian"]
  context    = "."
  dockerfile = "images/python/Dockerfile.debian"
  tags       = img_tags("python", "debian", true)
  contexts   = { dock-core = "target:core-debian" }
}

target "polyglot-debian" {
  inherits   = ["_common", "_cache-debian"]
  context    = "."
  dockerfile = "images/polyglot/Dockerfile.debian"
  args       = { DENO_VERSION = DENO_VERSION }
  tags       = img_tags("polyglot", "debian", true)
  contexts   = { dock-rust = "target:rust-debian" }
}

target "lint-debian" {
  inherits   = ["_common", "_cache-debian"]
  context    = "."
  dockerfile = "images/lint/Dockerfile.debian"
  tags       = img_tags("lint", "debian", false)
  contexts   = { dock-deno = "target:deno-debian" }
  platforms  = ["linux/amd64"]
}

target "std-debian" {
  inherits   = ["_common", "_cache-debian"]
  context    = "."
  dockerfile = "images/std/Dockerfile.debian"
  tags       = img_tags("std", "debian", false)
  contexts   = { dock-core = "target:core-debian" }
  platforms  = ["linux/amd64"]
}

target "pages-debian" {
  inherits   = ["_common", "_cache-debian"]
  context    = "."
  dockerfile = "images/pages/Dockerfile.debian"
  tags       = img_tags("pages", "debian", false)
  contexts   = { dock-core = "target:core-debian" }
  platforms  = ["linux/amd64"]
}

target "prose-debian" {
  inherits   = ["_common", "_cache-debian"]
  context    = "."
  dockerfile = "images/prose/Dockerfile.debian"
  tags       = img_tags("prose", "debian", true)
  contexts   = { dock-core = "target:core-debian" }
}

target "jvm-debian" {
  inherits   = ["_common", "_cache-debian"]
  context    = "."
  dockerfile = "images/jvm/Dockerfile.debian"
  tags       = img_tags("jvm", "debian", true)
  contexts   = { dock-core = "target:core-debian" }
}

target "android-debian" {
  inherits   = ["_common", "_cache-debian"]
  context    = "."
  dockerfile = "images/android/Dockerfile.debian"
  args = {
    ANDROID_PLATFORM_VERSION = ANDROID_PLATFORM_VERSION
  }
  tags = concat(
    img_tags("android", "debian", true),
    img_tags("android-${ANDROID_PLATFORM_VERSION}", "debian", true),
  )
  contexts = { dock-jvm = "target:jvm-debian" }
}

target "android-ndk-debian" {
  inherits   = ["_common", "_cache-debian"]
  context    = "."
  dockerfile = "images/android-ndk/Dockerfile.debian"
  args = {
    NDK_VERSION = "27.2.12479018"
  }
  tags = concat(
    img_tags("android-ndk", "debian", true),
    img_tags("android-ndk-${ANDROID_NDK_VERSION}", "debian", true),
  )
  contexts = { dock-android = "target:android-debian" }
}

# ---------------------------------------------------------------------------
# Groups
# ---------------------------------------------------------------------------

group "alpine" {
  targets = ["core", "rust", "deno", "node", "lint", "std", "pages"]
}

# Multi-arch targets (excludes lint, std, and pages which are amd64-only)
group "multiarch" {
  targets = ["core", "rust", "deno", "node"]
}

group "debian" {
  targets = [
    "core-debian",
    "rust-debian",
    "deno-debian",
    "node-debian",
    "python-debian",
    "polyglot-debian",
    "prose-debian",
    "jvm-debian",
    "android-debian",
    "android-ndk-debian",
  ]
}

group "default" {
  targets = ["alpine", "debian", "pages-debian", "lint-debian", "std-debian"]
}
