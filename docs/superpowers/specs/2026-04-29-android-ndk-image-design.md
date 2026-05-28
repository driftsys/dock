# Android NDK image design

## Problem

Teams building Rust libraries targeting Android (JNI, `.so` files for
mobile apps) need the Android NDK cross-compilation toolchains plus
Rust with Android targets configured. Currently they must install
these manually at CI time, which is slow and fragile.

## Solution

New Debian-only image `:android-ndk-debian` inheriting from
`:android-debian` that bundles:

- Android NDK 27 (r27c) — full, all 4 ABIs
- CMake (via sdkmanager)
- Rust stable (rustc, cargo, clippy, rustfmt)
- cargo-ndk
- 4 Rust Android targets pre-installed

## Inheritance tree

```
debian:bookworm-slim
  └── :core-debian
      └── :jvm-debian
          └── :android-debian (~485 MB)
              └── :android-ndk-debian (~2.5 GB)
```

## Tag scheme

Same dual-tag pattern as `:android-debian`:

| Tag                      | Meaning                       |
| ------------------------ | ----------------------------- |
| `:android-ndk-debian`    | Floating — latest NDK version |
| `:android-ndk-27-debian` | Pinned to NDK 27              |

When NDK 28 ships: bump, add `:android-ndk-28-debian`, move floating
tag. Old `:android-ndk-27-debian` stays frozen (deprecated).

## Installed components

| Component                       | Version              | Install method    |
| ------------------------------- | -------------------- | ----------------- |
| NDK                             | 27.2.12479018 (r27c) | sdkmanager        |
| CMake                           | 3.22.1+              | sdkmanager        |
| Rust                            | stable (latest)      | rustup            |
| cargo-ndk                       | latest               | cargo install     |
| Target: aarch64-linux-android   | —                    | rustup target add |
| Target: armv7-linux-androideabi | —                    | rustup target add |
| Target: x86_64-linux-android    | —                    | rustup target add |
| Target: i686-linux-android      | —                    | rustup target add |

## Environment variables

| Variable           | Value                              |
| ------------------ | ---------------------------------- |
| `ANDROID_NDK_HOME` | `${ANDROID_HOME}/ndk/<version>`    |
| `RUSTUP_HOME`      | `/usr/local/rustup`                |
| `CARGO_HOME`       | `/usr/local/cargo`                 |
| `PATH`             | Includes cargo bin + NDK toolchain |

## Dockerfile sketch

```dockerfile
FROM dock-android

ARG NDK_VERSION=27.2.12479018
ARG CMAKE_VERSION=3.22.1

# Install NDK + CMake via sdkmanager
RUN sdkmanager --install \
    "ndk;${NDK_VERSION}" \
    "cmake;${CMAKE_VERSION}"

ENV ANDROID_NDK_HOME="${ANDROID_HOME}/ndk/${NDK_VERSION}"

# Install Rust via rustup
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --default-toolchain stable --profile minimal \
        -c clippy -c rustfmt

# Add Android targets
RUN rustup target add \
    aarch64-linux-android \
    armv7-linux-androideabi \
    x86_64-linux-android \
    i686-linux-android

# Install cargo-ndk
RUN cargo install cargo-ndk

# Configure cargo for Android cross-compilation
# (cargo-ndk auto-detects ANDROID_NDK_HOME, but we also set
# linker paths in .cargo/config.toml for direct cargo builds)
```

## Build system changes

### docker-bake.hcl

```hcl
variable "ANDROID_NDK_VERSION" {
  default = "27"
}

target "android-ndk-debian" {
  inherits   = ["_common", "_cache-debian"]
  context    = "."
  dockerfile = "images/android-ndk/Dockerfile.debian"
  args = {
    NDK_VERSION = "27.2.12479018"
  }
  tags = [
    "${REGISTRY}:android-ndk-debian-${VERSION}${PLATFORM_SUFFIX}",
    "${REGISTRY}:android-ndk-debian${PLATFORM_SUFFIX}",
    "${REGISTRY}:android-ndk-${ANDROID_NDK_VERSION}-debian-${VERSION}${PLATFORM_SUFFIX}",
    "${REGISTRY}:android-ndk-${ANDROID_NDK_VERSION}-debian${PLATFORM_SUFFIX}",
    "${REGISTRY_DH}:android-ndk-debian-${VERSION}${PLATFORM_SUFFIX}",
    "${REGISTRY_DH}:android-ndk-debian${PLATFORM_SUFFIX}",
    "${REGISTRY_DH}:android-ndk-${ANDROID_NDK_VERSION}-debian-${VERSION}${PLATFORM_SUFFIX}",
    "${REGISTRY_DH}:android-ndk-${ANDROID_NDK_VERSION}-debian${PLATFORM_SUFFIX}",
  ]
  contexts = { dock-android = "target:android-debian" }
}
```

Add to `debian` group. Dependency chain: `jvm → android → android-ndk`.

### CI workflow

- `detect` job: `images/android-ndk/` → `android-ndk-debian`;
  `images/android/` changes also trigger `android-ndk-debian`
  (inheritance dependency)
- Test script mapping: `android-ndk-debian` → `tests/test_android_ndk.sh`

### Release workflow

Add `android-ndk-debian` and `android-ndk-${NDK}-debian` to manifest
merge list.

## Tests

`tests/test_android_ndk.sh`:

- NDK presence: `test -d "${ANDROID_NDK_HOME}"`
- NDK toolchains: verify
  `${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-*/bin/aarch64-linux-android*-clang`
  exists
- CMake: `cmake --version`
- Rust: `rustc --version`, `cargo --version`
- cargo-ndk: `cargo ndk --version`
- Rust targets: `rustup target list --installed` contains all 4
- Cross-compile sanity: create minimal Rust lib, run
  `cargo ndk -t arm64-v8a build` (verifies full toolchain works)

## Docs

- New page: `docs/images/android-ndk.md`
- Update: `docs/images/android.md` (mention NDK child image)
- Update: `README.md` catalog table
- Update: `docs/introduction.md` inheritance tree
- Update: `docs/versioning.md` (NDK pinned tag)
- Update: `AGENTS.md` inheritance tree

## CI usage example

```yaml
# Parallel native build across ABIs
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

## Size estimate

~2.5 GB:

- Base `:android-debian`: ~485 MB
- NDK 27 (all ABIs): ~1.5 GB
- CMake: ~50 MB
- Rust + targets: ~460 MB
- cargo-ndk: ~10 MB

## Scope exclusions

- No C++ STL selection (uses NDK default: libc++)
- No Gradle pre-installed (comes from project wrapper)
- No Android emulator/AVD (too large, CI runners provide this)
- No pre-built `.cargo/config.toml` for all targets (cargo-ndk
  handles this automatically)
