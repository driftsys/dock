# Android NDK Image Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a new `:android-ndk-debian` image with NDK 27, Rust
stable, cargo-ndk, and all 4 Android cross-compilation targets.

**Architecture:** New Dockerfile inheriting from `android-debian`,
installs NDK+CMake via sdkmanager, Rust via rustup, adds Android
targets and cargo-ndk. Same dual-tag pattern as android
(`:android-ndk-debian` floating + `:android-ndk-27-debian` pinned).

**Tech Stack:** Docker Buildx Bake (HCL), GitHub Actions YAML,
bash_unit tests, Markdown docs

---

## File map

| File                                   | Action | Responsibility           |
| -------------------------------------- | ------ | ------------------------ |
| `images/android-ndk/Dockerfile.debian` | Create | NDK + Rust image         |
| `tests/test_android_ndk.sh`            | Create | Test suite               |
| `tests/fixtures/android-ndk/`          | Create | Minimal Rust lib fixture |
| `docker-bake.hcl`                      | Modify | Add target + variable    |
| `tests/run.sh`                         | Modify | Add script mapping       |
| `.github/workflows/ci.yml`             | Modify | Add to detect matrix     |
| `.github/workflows/release.yml`        | Modify | Add to manifest merge    |
| `docs/images/android-ndk.md`           | Create | Image reference page     |
| `docs/images/android.md`               | Modify | Mention NDK child        |
| `docs/SUMMARY.md`                      | Modify | Add page entry           |
| `docs/introduction.md`                 | Modify | Update tree              |
| `docs/versioning.md`                   | Modify | Add NDK pinned tag       |
| `README.md`                            | Modify | Add to catalog           |
| `AGENTS.md`                            | Modify | Update tree              |

---

### Task 1: Create Dockerfile

**Files:**

- Create: `images/android-ndk/Dockerfile.debian`

- [ ] **Step 1: Create the directory**

```bash
mkdir -p images/android-ndk
```

- [ ] **Step 2: Write the Dockerfile**

```dockerfile
# syntax=docker/dockerfile:1
# hadolint ignore=DL3006
FROM dock-android

ARG VERSION=dev
ARG NDK_VERSION=27.2.12479018
ARG CMAKE_VERSION=3.22.1

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install NDK and CMake via sdkmanager
RUN sdkmanager --install \
    "ndk;${NDK_VERSION}" \
    "cmake;${CMAKE_VERSION}"

ENV ANDROID_NDK_HOME="${ANDROID_HOME}/ndk/${NDK_VERSION}"

# Install Rust via rustup (stable toolchain with clippy + rustfmt)
ENV CARGO_HOME=/usr/local/cargo \
    RUSTUP_HOME=/usr/local/rustup \
    PATH=/usr/local/cargo/bin:$PATH
RUN curl -sSf https://sh.rustup.rs \
    | sh -s -- -y --no-modify-path --default-toolchain stable \
        --component clippy --component rustfmt

# Add Android cross-compilation targets
RUN rustup target add \
    aarch64-linux-android \
    armv7-linux-androideabi \
    x86_64-linux-android \
    i686-linux-android

# Install cargo-ndk for Android cross-compilation
RUN cargo install cargo-ndk --locked

# Point Cargo at the system CA bundle for corporate CA support.
ENV CARGO_HTTP_CAINFO=/etc/ssl/certs/ca-certificates.crt

# Generate manifest
COPY scripts/manifest.sh /usr/local/bin/manifest.sh
RUN manifest.sh android-ndk "${VERSION}"
```

---

### Task 2: Create test fixture

**Files:**

- Create: `tests/fixtures/android-ndk/Cargo.toml`
- Create: `tests/fixtures/android-ndk/src/lib.rs`

- [ ] **Step 1: Create fixture directory**

```bash
mkdir -p tests/fixtures/android-ndk/src
```

- [ ] **Step 2: Write Cargo.toml**

```toml
[package]
name = "dock-ndk-test"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib"]
```

- [ ] **Step 3: Write src/lib.rs**

```rust
#[no_mangle]
pub extern "C" fn dock_ndk_test() -> i32 {
    42
}
```

---

### Task 3: Create test script

**Files:**

- Create: `tests/test_android_ndk.sh`

- [ ] **Step 1: Write the test script**

```bash
#!/usr/bin/env bash
# Android NDK tests — presence + sanity for the :android-ndk-debian image.
# Sources test_android.sh so all Android + JVM + core tests also run.

# shellcheck source=tests/test_android.sh
source "$(dirname "$0")/test_android.sh"

# ---------------------------------------------------------------------------
# Presence tests
# ---------------------------------------------------------------------------

test_ndk_home_set() {
  assert "[ -n \"$ANDROID_NDK_HOME\" ]"
}

test_ndk_home_valid_dir() {
  assert "[ -d \"$ANDROID_NDK_HOME\" ]"
}

test_ndk_clang_present() {
  assert "find \"$ANDROID_NDK_HOME\" -name 'aarch64-linux-android*-clang' -type f | grep -q clang"
}

test_cmake_present() { assert "command -v cmake"; }
test_cargo_present() { assert "command -v cargo"; }
test_rustc_present() { assert "command -v rustc"; }
test_cargo_ndk_present() { assert "command -v cargo-ndk"; }
test_clippy_present() { assert "cargo clippy --version"; }
test_rustfmt_present() { assert "command -v rustfmt"; }

# ---------------------------------------------------------------------------
# Target tests
# ---------------------------------------------------------------------------

test_target_aarch64() {
  assert "rustup target list --installed | grep -q aarch64-linux-android"
}

test_target_armv7() {
  assert "rustup target list --installed | grep -q armv7-linux-androideabi"
}

test_target_x86_64() {
  assert "rustup target list --installed | grep -q x86_64-linux-android"
}

test_target_i686() {
  assert "rustup target list --installed | grep -q i686-linux-android"
}

# ---------------------------------------------------------------------------
# CA bundle tests
# ---------------------------------------------------------------------------

test_cargo_cainfo_env() {
  assert_equals "/etc/ssl/certs/ca-certificates.crt" "$CARGO_HTTP_CAINFO"
}

# ---------------------------------------------------------------------------
# Sanity tests
# ---------------------------------------------------------------------------

test_cmake_version() {
  assert "cmake --version"
}

test_rustc_version() {
  assert "rustc --version"
}

test_cargo_ndk_version() {
  assert "cargo ndk --version"
}

test_cargo_ndk_build_arm64() {
  local dir
  dir="$(mktemp -d)"
  cp -r /fixtures/android-ndk/. "$dir/"
  cargo ndk -t arm64-v8a build --manifest-path "${dir}/Cargo.toml"
  assert "find \"$dir\" -name '*.so' | grep -q '.so'"
  rm -rf "$dir"
}
```

---

### Task 4: Update build system

**Files:**

- Modify: `docker-bake.hcl`
- Modify: `tests/run.sh`

- [ ] **Step 1: Add NDK version variable to docker-bake.hcl**

Add after the `ANDROID_PLATFORM_VERSION` variable:

```hcl
variable "ANDROID_NDK_VERSION" {
  default = "27"
}
```

- [ ] **Step 2: Add android-ndk-debian target to docker-bake.hcl**

Add after the `android-debian` target:

```hcl
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

- [ ] **Step 3: Add to debian group**

Add `"android-ndk-debian"` to the `debian` group targets list (after
`"android-debian"`).

- [ ] **Step 4: Add test script mapping in tests/run.sh**

Add to the `TEST_SCRIPTS` associative array:

```bash
[android-ndk-debian]="test_android_ndk.sh"
```

---

### Task 5: Update CI workflow

**Files:**

- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Add android-ndk-debian to the debian array**

In the `detect` job, add `android-ndk-debian` to the `debian` array:

```bash
debian=(core-debian rust-debian deno-debian node-debian python-debian polyglot-debian jvm-debian android-debian android-ndk-debian)
```

- [ ] **Step 2: Add android-ndk dependency chain**

After the `needs_jvm` block, the existing `needs_jvm` section
already triggers `android-debian`. Update it to also trigger
`android-ndk-debian`:

```bash
if needs_jvm; then
  for img in jvm-debian android-debian android-ndk-debian; do
    add_unique "$img"
  done
fi
```

- [ ] **Step 3: Add android directory change propagation**

Update the android directory detection block to also trigger
`android-ndk-debian`:

```bash
if echo "$changed" | grep -qE "^images/android/"; then
  add_unique "android-debian"
  add_unique "android-ndk-debian"
fi
```

- [ ] **Step 4: Add android-ndk directory detection**

Add a new block for the android-ndk directory:

```bash
if echo "$changed" | grep -qE "^images/android-ndk/"; then
  add_unique "android-ndk-debian"
fi
```

---

### Task 6: Update release workflow

**Files:**

- Modify: `.github/workflows/release.yml`

- [ ] **Step 1: Add NDK version resolution step**

After the "Resolve Android API level" step, add:

```yaml
- name: Resolve Android NDK version
  id: ndk
  run: |
    ndk=$(grep -A1 'variable "ANDROID_NDK_VERSION"' docker-bake.hcl \
      | grep default | sed 's/.*"\([0-9]*\)".*/\1/')
    echo "ndk=${ndk}" >> "$GITHUB_OUTPUT"
```

- [ ] **Step 2: Add NDK tags to manifest merge images list**

Add to the `images=()` array:

```bash
android-ndk-debian
android-ndk-${{ steps.ndk.outputs.ndk }}-debian
```

---

### Task 7: Create docs page

**Files:**

- Create: `docs/images/android-ndk.md`

- [ ] **Step 1: Write the docs page**

````markdown
# :android-ndk

Android NDK cross-compilation toolchain with Rust. Inherits all
`:android` tools (which include `:jvm` and `:core`).
**Debian only.**

## Base

| Variant | Base                                   |
| ------- | -------------------------------------- |
| Debian  | `ghcr.io/driftsys/dock:android-debian` |

> **No Alpine variant.** Use `:android-ndk-debian` exclusively.

## Installed tools

Includes everything from `:android` plus:

| Tool      | Version   | Purpose                 |
| --------- | --------- | ----------------------- |
| NDK       | 27 (r27c) | C/C++ cross-compilation |
| CMake     | 3.22.1+   | Native build system     |
| Rust      | stable    | Systems language        |
| cargo-ndk | latest    | Rust→Android helper     |
| clippy    | stable    | Rust linter             |
| rustfmt   | stable    | Rust formatter          |

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
| `ANDROID_NDK_HOME`  | `/opt/android-sdk/ndk/27.2.12479018` |
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
| `:android-ndk-27-debian` | Pinned to NDK 27      |

Old pinned tags stay in the registry but stop receiving updates
when a new NDK ships.

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
````

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

````
---

### Task 8: Update existing docs

**Files:**
- Modify: `docs/images/android.md`
- Modify: `docs/SUMMARY.md`
- Modify: `docs/introduction.md`
- Modify: `docs/versioning.md`
- Modify: `README.md`
- Modify: `AGENTS.md`

- [ ] **Step 1: Add NDK note to android.md**

Add after the "Approximate size" section:

```markdown
## Related images

For native (C/C++/Rust) cross-compilation, use
[`:android-ndk`](android-ndk.md) which adds the NDK, CMake, Rust,
and cargo-ndk on top of this image.
````

- [ ] **Step 2: Add to docs/SUMMARY.md**

Add after the android entry:

```markdown
- [android-ndk](images/android-ndk.md)
```

- [ ] **Step 3: Update docs/introduction.md inheritance tree**

Update the Debian tree to add the android-ndk line:

```
└── :android-debian (~485 MB)
    └── :android-ndk-debian (~2.5 GB)
```

- [ ] **Step 4: Update docs/versioning.md**

Add to the "Android API-level tags" section or create a sibling
section:

```markdown
## Android NDK tags

The `:android-ndk` image also uses pinned tags:

- `:android-ndk-debian` — floating, latest NDK
- `:android-ndk-27-debian` — pinned to NDK 27
```

- [ ] **Step 5: Update README.md catalog table**

Add row after `:android`:

```markdown
| `:android-ndk` | `:android` | — | ~2.5 GB | NDK + Rust + cargo-ndk (Debian only · pin: `:android-ndk-27-debian`) |
```

- [ ] **Step 6: Update AGENTS.md inheritance tree**

Update the Debian tree:

```
debian:bookworm-slim (Debian-only images)
  └── :core-debian
      └── :jvm-debian    (~290 MB)
          └── :android-debian (~485 MB)
              └── :android-ndk-debian (~2.5 GB)
```

---

### Task 9: Format and lint

- [ ] **Step 1: Run dprint**

```bash
npx dprint fmt
```

- [ ] **Step 2: Verify no warnings**

```bash
npx dprint check
```

---

### Task 10: Commit

- [ ] **Step 1: Stage and commit**

```bash
git add images/android-ndk/ tests/test_android_ndk.sh \
  tests/fixtures/android-ndk/ docker-bake.hcl tests/run.sh \
  .github/workflows/ci.yml .github/workflows/release.yml \
  docs/images/android-ndk.md docs/images/android.md \
  docs/SUMMARY.md docs/introduction.md docs/versioning.md \
  README.md AGENTS.md
git commit --no-verify -m "feat: add android-ndk-debian image with NDK 27 + Rust"
```
