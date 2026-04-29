# :android

Android SDK toolchain. Inherits all `:jvm` tools (which include all
`:core` tools). **Debian only** — inherits the Debian-only constraint
from `:jvm`.

## Base

| Variant | Base                                      |
| ------- | ----------------------------------------- |
| Debian  | `ghcr.io/driftsys/dock:jvm-debian` (build |
|         | context)                                  |

> **No Alpine variant.** Use `:android-debian` exclusively.

## Installed tools

Includes everything from `:jvm` plus:

| Tool           | Install method        | Purpose               |
| -------------- | --------------------- | --------------------- |
| sdkmanager     | Android cmdline-tools | SDK component manager |
| platform-tools | sdkmanager            | adb, fastboot         |
| build-tools    | sdkmanager            | aapt2, d8, zipalign   |
| platforms      | sdkmanager            | Android SDK platform  |

## Environment variables

| Variable           | Value                          |
| ------------------ | ------------------------------ |
| `ANDROID_HOME`     | `/opt/android-sdk`             |
| `ANDROID_SDK_ROOT` | `/opt/android-sdk`             |
| `JAVA_HOME`        | `/usr/lib/jvm/java-17-openjdk` |

## Build arguments

| Argument                        | Default    | Description           |
| ------------------------------- | ---------- | --------------------- |
| `ANDROID_CMDLINE_TOOLS_VERSION` | `14742923` | cmdline-tools release |
| `ANDROID_BUILD_TOOLS_VERSION`   | `36.1.0`   | Build tools version   |
| `ANDROID_PLATFORM_VERSION`      | `36`       | Platform SDK version  |

## Corporate CA support

Inherits JKS truststore support from `:jvm`. `sdkmanager` uses
the Java trust store, so corporate CAs are automatically trusted
after running `dock-bootstrap`.

## Usage in CI

### GitHub Actions

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    container: ghcr.io/driftsys/dock:android-debian
    steps:
      - uses: actions/checkout@v4
      - run: sdkmanager --version
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
    - sdkmanager --version
    - ./gradlew assembleDebug
```

## Path note

`aapt2` and other build-tools binaries live inside
`${ANDROID_HOME}/build-tools/<version>/` and are **not** on
`$PATH` by default. Use the full path or add it yourself:

```bash
export PATH="${ANDROID_HOME}/build-tools/36.1.0:${PATH}"
```

## SDK version policy

This image ships the **latest stable Android API level only**. The SDK
platform, build-tools, and command-line tools are bumped manually when
Google releases a new stable API level (typically once per year at
Google I/O or shortly after).

**Current baseline:** API 36 (Android 16).

**Rationale:** Google Play Store requires `targetSdk` at the latest
stable level within ~1 year of release (e.g., targetSdk 35+ required
since Aug 31 2025). Shipping the latest stable level keeps CI images
aligned with Play Store policy without chasing beta releases.

**Update cadence:**

- Watch [Android API levels](https://developer.android.com/tools/releases/platforms)
  for new stable releases.
- Bump `ANDROID_PLATFORM_VERSION` and `ANDROID_BUILD_TOOLS_VERSION`
  in `images/android/Dockerfile.debian`.
- Update the test assertion in `tests/test_android.sh`.
- Cut a new dock release (minor version bump).

## Pinning to an API level

Each release publishes both a floating tag and an API-level-pinned
tag:

| Tag                  | Meaning                             |
| -------------------- | ----------------------------------- |
| `:android-debian`    | Always the current stable API level |
| `:android-36-debian` | Pinned to API 36                    |

**Use the floating tag** (`:android-debian`) to stay current
automatically. **Use the pinned tag** (`:android-36-debian`) when
your project cannot yet upgrade.

### Deprecation policy

When we bump to a new API level (e.g., 37), the old pinned tag
(`:android-36-debian`) stays in the registry but is **no longer
rebuilt**. It will not receive OS or JDK security patches. Migrate
to the new API level as soon as possible.

### Examples

```yaml
# Always latest (recommended)
image: ghcr.io/driftsys/dock:android-debian

# Pinned to API 36
image: ghcr.io/driftsys/dock:android-36-debian

# Pinned to API 36, specific dock release
image: ghcr.io/driftsys/dock:android-36-debian-0.1.9
```

## Approximate size

| Variant | Size    |
| ------- | ------- |
| Alpine  | —       |
| Debian  | ~485 MB |
