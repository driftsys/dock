# JVM and Android Docker images — Design spec

**Date:** 2026-04-23
**Status:** Draft
**Epic:** TBD (new epic for JVM/Android images)

## Problem

Teams building Android projects on CI need a JDK and the Android SDK
command-line tools. The Android SDK ships as glibc-linked ELF
binaries — it cannot run on Alpine/musl. There is no maintained,
minimal, public Docker image for Android CI; the closest
(`cimg/android`) ships 3 JDKs, 6+ platform SDKs, Ruby, Fastlane,
gcloud, and weighs ~3.2 GB.

dock has no JVM or Android image today.

## Decision summary

| Question           | Decision                                       |
| ------------------ | ---------------------------------------------- |
| Alpine variant?    | No — Android SDK is glibc-only                 |
| Polyglot gets JDK? | No — keep polyglot focused (Rust+Deno+Python)  |
| JDK version        | 17 only (required by Gradle 8+/AGP 8+)         |
| JDK distribution   | `openjdk-17-jdk-headless` from Debian repos    |
| Ship Gradle?       | No — projects use the Gradle Wrapper           |
| Android SDK scope  | cmdline-tools + build-tools + one platform SDK |
| Future: NDK?       | Possible `-ndk` variant later, out of scope    |

## Architecture

### Inheritance tree (Debian side, additions in bold)

```text
debian:bookworm-slim
  └── :core-debian           (~90 MB)
      ├── :rust-debian       (~320 MB)
      │   └── :polyglot-debian (~450 MB)
      ├── :deno-debian       (~170 MB)
      ├── :node-debian       (~165 MB)
      ├── :python-debian     (~105 MB)
      └── :jvm-debian        (~290 MB)     ← NEW
          └── :android-debian (~485 MB)    ← NEW
```

Both images are **Debian-only** — no Alpine variant.

### `:jvm-debian` — JDK 17 headless on core-debian

**Base:** `dock-core` (resolved to `core-debian` via bake contexts)

**Packages:**

- `openjdk-17-jdk-headless` (from Debian bookworm repos)

**Environment:**

```dockerfile
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-${TARGETARCH_DEB}
ENV PATH="${JAVA_HOME}/bin:${PATH}"
```

Note: Debian names the JDK directory with the dpkg architecture
(`amd64`, `arm64`). The Dockerfile must resolve this at build time,
e.g. via `dpkg --print-architecture` in a `RUN` step that writes
`JAVA_HOME` to a file, or by using a shell wrapper. Alternatively,
use the architecture-independent symlink if Debian provides one
(check `/usr/lib/jvm/java-17-openjdk-*`).

**CA trust:** Debian's `ca-certificates-java` package (pulled in as
a dependency of `openjdk-17-jdk-headless`) hooks into
`update-ca-certificates` to auto-populate the JKS truststore at
`${JAVA_HOME}/lib/security/cacerts`. This means:

- **Normal path** (writable `/etc/ssl/certs/`): `dock-bootstrap` →
  `update-ca-certificates` → JKS truststore updated automatically.
  No extra work needed.
- **Read-only fallback** (K8s runners): The JKS truststore is
  inside the image and already contains the default CAs. Corporate
  CAs in the PEM fallback bundle (`/etc/dock/ca-bundle.crt`) are
  NOT automatically reflected in the JKS store. Two options:
  1. Extend `dock-bootstrap` to detect `keytool` on PATH and
     import certs into a writable copy of the JKS truststore, then
     set `JAVA_TOOL_OPTIONS` to point at it.
  2. Document that on read-only K8s runners, JVM tools (Gradle,
     Maven) may need manual `keytool -importcert` calls.

  **Recommendation:** Option 1 — extend `dock-bootstrap`. The
  script already handles the read-only fallback; adding a JVM
  branch keeps the "just run dock-bootstrap" promise. Implementation
  detail: copy `cacerts` to `/etc/dock/cacerts`, import PEM certs
  via `keytool`, add `-Djavax.net.ssl.trustStore=/etc/dock/cacerts`
  to `JAVA_TOOL_OPTIONS` in `ca.env`.

**Manifest:** `manifest.sh jvm "${VERSION}"`

### `:android-debian` — Android SDK on jvm-debian

**Base:** `dock-jvm` (resolved to `jvm-debian` via bake contexts)

**Installed SDK components:**

| Component              | Version | Size    |
| ---------------------- | ------- | ------- |
| `cmdline-tools;latest` | latest  | ~150 MB |
| `platform-tools`       | latest  | ~15 MB  |
| `build-tools;36.1.0`   | 36.1.0  | ~65 MB  |
| `platforms;android-36` | API 36  | ~70 MB  |

**Build args** (for version pinning):

```dockerfile
ARG ANDROID_CMDLINE_TOOLS_VERSION=14742923
ARG ANDROID_BUILD_TOOLS_VERSION=36.1.0
ARG ANDROID_PLATFORM_VERSION=36
```

**Installation steps:**

1. Download `commandlinetools-linux-${VERSION}_latest.zip` from
   `https://dl.google.com/android/repository/`
2. Unzip to `${ANDROID_HOME}/cmdline-tools/latest/`
3. Accept licenses: `yes | sdkmanager --licenses`
4. Install components via `sdkmanager`
5. Clean up zip files

**Environment:**

```dockerfile
ENV ANDROID_HOME=/opt/android-sdk
ENV ANDROID_SDK_ROOT=${ANDROID_HOME}
ENV PATH="${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${PATH}"
```

**Manifest:** `manifest.sh android "${VERSION}"`

### Users install additional SDKs at CI time

```yaml
# .gitlab-ci.yml
android-build:
  image: ghcr.io/driftsys/dock:android-debian
  before_script:
    - dock-bootstrap
    - . /etc/dock/ca.env 2>/dev/null || true
    # Install additional platform SDKs if needed:
    - sdkmanager "platforms;android-34" "platforms;android-35"
  script:
    - ./gradlew assembleDebug
```

## Testing

### `:jvm-debian` tests (`tests/test_jvm.sh`)

**Presence tests:**

- `java` on PATH
- `javac` on PATH
- `keytool` on PATH

**Sanity tests:**

- `java -version` exits 0 and outputs `openjdk version "17.`
- `javac -version` exits 0
- `JAVA_HOME` is set and points to a valid directory
- JKS truststore exists at `${JAVA_HOME}/lib/security/cacerts`

### `:android-debian` tests (`tests/test_android.sh`)

**Presence tests:**

- `sdkmanager` on PATH
- `aapt2` on PATH

**Sanity tests:**

- `sdkmanager --list` exits 0 (proves JDK + cmdline-tools work)
- `aapt2 version` exits 0
- `ANDROID_HOME` is set and points to a valid directory
- `ANDROID_SDK_ROOT` is set

**Out of scope for bash_unit:**

Full Gradle build integration test (requires network, Gradle
download, ~100 MB of Maven artifacts). Can be added as a separate
CI-only job later.

## Build system changes

### `docker-bake.hcl` additions

```hcl
target "jvm-debian" {
  inherits   = ["_common", "_cache-debian"]
  context    = "."
  dockerfile = "images/jvm/Dockerfile.debian"
  tags = [
    "${REGISTRY}:jvm-debian-${VERSION}${PLATFORM_SUFFIX}",
    "${REGISTRY}:jvm-debian${PLATFORM_SUFFIX}",
    "${REGISTRY_DH}:jvm-debian-${VERSION}${PLATFORM_SUFFIX}",
    "${REGISTRY_DH}:jvm-debian${PLATFORM_SUFFIX}",
  ]
  contexts = { dock-core = "target:core-debian" }
}

target "android-debian" {
  inherits   = ["_common", "_cache-debian"]
  context    = "."
  dockerfile = "images/android/Dockerfile.debian"
  tags = [
    "${REGISTRY}:android-debian-${VERSION}${PLATFORM_SUFFIX}",
    "${REGISTRY}:android-debian${PLATFORM_SUFFIX}",
    "${REGISTRY_DH}:android-debian-${VERSION}${PLATFORM_SUFFIX}",
    "${REGISTRY_DH}:android-debian${PLATFORM_SUFFIX}",
  ]
  contexts = { dock-jvm = "target:jvm-debian" }
}
```

Add both targets to the `debian` group.

### CI matrix

Add `jvm` and `android` to the CI test matrix (Debian variant
only — no Alpine).

## Files to create/modify

| File                               | Action                                                 |
| ---------------------------------- | ------------------------------------------------------ |
| `images/jvm/Dockerfile.debian`     | Create                                                 |
| `images/android/Dockerfile.debian` | Create                                                 |
| `tests/test_jvm.sh`                | Create                                                 |
| `tests/test_android.sh`            | Create                                                 |
| `docker-bake.hcl`                  | Add jvm-debian, android-debian targets + group         |
| `scripts/dock-bootstrap.sh`        | Extend: JKS truststore handling when `keytool` present |
| `README.md`                        | Add jvm and android to image catalog                   |
| `docs/extending.md`                | Add JVM/Android usage examples                         |
| `AGENTS.md`                        | Update inheritance tree                                |

## Future considerations (out of scope)

- **`:android-ndk-debian`** — NDK variant (~1.5 GB extra). Separate
  image inheriting from `:android-debian`. Only if demand warrants.
- **JDK 21** — when AGP officially requires it (expected ~2026-2027),
  bump `openjdk-17` to `openjdk-21`.
- **Gradle distribution mirror** — org-specific, not baked into the
  image. Document in `docs/extending.md`.
