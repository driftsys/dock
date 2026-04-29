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

## Approximate size

| Variant | Size    |
| ------- | ------- |
| Alpine  | —       |
| Debian  | ~485 MB |
