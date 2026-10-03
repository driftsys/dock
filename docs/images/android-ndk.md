# :android-ndk

Android NDK cross-compilation toolchain with Rust. Inherits all `:android` tools
(which include `:jvm` and `:core`). **Debian only.**

## Base

| Variant | Base                                   |
| ------- | -------------------------------------- |
| Debian  | `ghcr.io/driftsys/dock:android-debian` |

> **No Alpine variant.** Use `:android-ndk-debian` exclusively.

## Installed tools

Includes everything from `:android` plus:

| Tool      | Version  | Purpose                 |
| --------- | -------- | ----------------------- |
| NDK       | 30 (LTS) | C/C++ cross-compilation |
| CMake     | 4.1.2    | Native build system     |
| Rust      | stable   | Systems language        |
| cargo-ndk | latest   | Rust→Android helper     |
| clippy    | stable   | Rust linter             |
| rustfmt   | stable   | Rust formatter          |

## Rust Android targets

All 4 Android ABIs are pre-installed:

| Target                    | ABI         |
| ------------------------- | ----------- |
| `aarch64-linux-android`   | arm64-v8a   |
| `armv7-linux-androideabi` | armeabi-v7a |
| `x86_64-linux-android`    | x86_64      |
| `i686-linux-android`      | x86         |

## Environment variables

| Variable            | Value                                |
| ------------------- | ------------------------------------ |
| `ANDROID_NDK_HOME`  | `/opt/android-sdk/ndk/30.0.16248370` |
| `ANDROID_HOME`      | `/opt/android-sdk`                   |
| `JAVA_HOME`         | `/usr/lib/jvm/java-17-openjdk`       |
| `CARGO_HOME`        | `/usr/local/cargo`                   |
| `RUSTUP_HOME`       | `/usr/local/rustup`                  |
| `CARGO_HTTP_CAINFO` | `/etc/ssl/certs/ca-certificates.crt` |

## Pinning to an NDK version

Same scheme as `:android-debian`:

| Tag                      | Meaning               |
| ------------------------ | --------------------- |
| `:android-ndk-debian`    | Floating — latest NDK |
| `:android-ndk-30-debian` | Pinned to NDK 30      |

Old pinned tags stay in the registry but stop receiving updates when a new NDK
ships.

## Corporate CA support

Inherits JKS truststore support from `:jvm`. Both `sdkmanager` and `cargo` use
the system CA bundle after running `dock-bootstrap`.

## Usage in CI

### Parallel cross-compilation (GitLab CI)

```yaml
build-native:
  image: ghcr.io/driftsys/dock:android-ndk-debian
  parallel:
    matrix:
      - ABI: [arm64-v8a, armeabi-v7a, x86_64, x86]
  before_script:
    - dock-bootstrap
    - . /etc/dock/ca.env 2>/dev/null || true
  script:
    - cargo ndk -t $ABI build --release
  artifacts:
    paths:
      - target/*/release/*.so
```

### GitHub Actions

```yaml
jobs:
  build-native:
    runs-on: ubuntu-latest
    container: ghcr.io/driftsys/dock:android-ndk-debian
    strategy:
      matrix:
        abi: [arm64-v8a, armeabi-v7a, x86_64, x86]
    steps:
      - uses: actions/checkout@v4
      - run: cargo ndk -t ${{ matrix.abi }} build --release
```

## Approximate size

| Variant | Size    |
| ------- | ------- |
| Alpine  | —       |
| Debian  | ~2.5 GB |
