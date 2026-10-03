# :android

Android SDK toolchain. Inherits all `:jvm` tools (which include all `:core`
tools). **Debian only** — inherits the Debian-only constraint from `:jvm`.

## Base

| Variant | Base                                      |
| ------- | ----------------------------------------- |
| Debian  | `ghcr.io/driftsys/dock:jvm-debian` (build |
|         | context)                                  |

> **No Alpine variant.** Use `:android-debian` exclusively.

Google's installed Linux SDK packages contain x86-64 native executables. Use an
`amd64` runner for `adb`, `aapt2`, and the other native SDK tools. The `arm64`
image includes Google's native arm64 Android CLI for SDK management, but native
SDK execution remains unsupported until compatible binaries are provided.

## Installed tools

Includes everything from `:jvm` plus:

| Tool           | Install method        | Purpose               |
| -------------- | --------------------- | --------------------- |
| android        | Android cmdline-tools | SDK component manager |
| platform-tools | android sdk           | adb, fastboot         |
| build-tools    | android sdk           | aapt2, d8, zipalign   |
| platforms      | android sdk           | Android SDK platform  |

The current command-line tools include `android sdk`, which replaces
`sdkmanager`. The deprecated `sdkmanager` wrapper remains available for existing
pipelines and emits an upstream deprecation warning when invoked. The image
build and tests use `android sdk`.

The Linux command-line tools archive bundles an x86-64 launcher. The arm64 image
replaces it with Google's official arm64 launcher. Both launchers fetch their
current CLI payload during SDK installation.

## Environment variables

| Variable           | Value                          |
| ------------------ | ------------------------------ |
| `ANDROID_HOME`     | `/opt/android-sdk`             |
| `ANDROID_SDK_ROOT` | `/opt/android-sdk`             |
| `JAVA_HOME`        | `/usr/lib/jvm/java-17-openjdk` |

## Build arguments

| Argument                        | Default    | Description           |
| ------------------------------- | ---------- | --------------------- |
| `ANDROID_CMDLINE_TOOLS_VERSION` | `16111833` | cmdline-tools release |
| `ANDROID_BUILD_TOOLS_VERSION`   | `37.0.0`   | Build tools version   |
| `ANDROID_PLATFORM_VERSION`      | `37.2`     | Platform SDK version  |

## Corporate CA support

Inherits JKS truststore support from `:jvm`. `sdkmanager` uses the Java trust
store, so corporate CAs are automatically trusted after running
`dock-bootstrap`.

## Usage in CI

### GitHub Actions

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    container: ghcr.io/driftsys/dock:android-debian
    steps:
      - uses: actions/checkout@v4
      - run: android --version
      - run: ./gradlew assembleDebug
```

### GitLab CI

```yaml
build:
  image: ghcr.io/driftsys/dock:android-debian
  before_script:
    - dock-bootstrap
    - . /etc/dock/ca.env 2>/dev/null || true
  script:
    - android --version
    - ./gradlew assembleDebug
```

## Path note

`aapt2` and other build-tools binaries live inside
`${ANDROID_HOME}/build-tools/<version>/` and are **not** on `$PATH` by default.
Use the full path or add it yourself:

```bash
export PATH="${ANDROID_HOME}/build-tools/37.0.0:${PATH}"
```

## SDK version policy

This image ships the **latest stable Android API level only**. The SDK platform,
build-tools, and command-line tools are bumped manually when Google releases a
new stable API level (typically once per year at Google I/O or shortly after).

**Current baseline:** API 37.2 (Android 17).

**Rationale:** Google Play Store requires `targetSdk` at the latest stable level
within ~1 year of release (e.g., targetSdk 35+ required since Aug 31 2025).
Shipping the latest stable level keeps CI images aligned with Play Store policy
without chasing beta releases.

**Update cadence:**

- Watch
  [Android API levels](https://developer.android.com/tools/releases/platforms)
  for new stable releases.
- Bump `ANDROID_PLATFORM_VERSION` and `ANDROID_BUILD_TOOLS_VERSION` in
  `images/android/Dockerfile.debian`.
- Update the test assertion in `tests/test_android.sh`.
- Cut a new dock release (minor version bump).

## Pinning to an API level

Each release publishes both a floating tag and an API-level-pinned tag:

| Tag                    | Meaning                             |
| ---------------------- | ----------------------------------- |
| `:android-debian`      | Always the current stable API level |
| `:android-37.2-debian` | Pinned to API 37.2                  |

**Use the floating tag** (`:android-debian`) to stay current automatically.
**Use the pinned tag** (`:android-37.2-debian`) when your project cannot yet
upgrade.

### Deprecation policy

When we bump to a new API level (e.g., 38), the old pinned tag
(`:android-37.2-debian`) stays in the registry but is **no longer rebuilt**. It
will not receive OS or JDK security patches. Migrate to the new API level as
soon as possible.

### Examples

```yaml
# Always latest (recommended)
image: ghcr.io/driftsys/dock:android-debian

# Pinned to API 37.2
image: ghcr.io/driftsys/dock:android-37.2-debian

# Pinned to API 37.2, specific dock release
image: ghcr.io/driftsys/dock:android-37.2-debian-${DOCK_VERSION}
```

## Approximate size

Compressed download size for `linux/amd64`.

| Variant | Size    |
| ------- | ------- |
| Alpine  | —       |
| Debian  | ~525 MB |

## Related images

For native (C/C++/Rust) cross-compilation, use [`:android-ndk`](android-ndk.md)
which adds the NDK, CMake, Rust, and cargo-ndk on top of this image.
