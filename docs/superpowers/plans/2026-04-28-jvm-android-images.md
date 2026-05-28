# JVM and Android Docker Images — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `:jvm-debian` and `:android-debian` images to the dock
image library, including Dockerfiles, build system integration, tests,
dock-bootstrap JKS support, and documentation updates.

**Architecture:** Two new Debian-only images. `:jvm-debian` inherits
from `:core-debian` and adds JDK 17 headless. `:android-debian`
inherits from `:jvm-debian` and adds Android SDK command-line tools,
build-tools, and one platform SDK. `dock-bootstrap` is extended to
handle JKS truststore updates on read-only filesystems.

**Tech Stack:** Docker (BuildKit + bake), POSIX shell, bash_unit,
OpenJDK 17, Android SDK cmdline-tools

---

## File Map

| File                               | Action | Responsibility                             |
| ---------------------------------- | ------ | ------------------------------------------ |
| `images/jvm/Dockerfile.debian`     | Create | JDK 17 headless image                      |
| `images/android/Dockerfile.debian` | Create | Android SDK image                          |
| `tests/test_jvm.sh`                | Create | JVM presence + sanity tests                |
| `tests/test_android.sh`            | Create | Android SDK presence + sanity tests        |
| `scripts/dock-bootstrap.sh`        | Modify | Add JKS truststore fallback                |
| `docker-bake.hcl`                  | Modify | Add targets + update debian group          |
| `tests/run.sh`                     | Modify | Add jvm/android to test map                |
| `README.md`                        | Modify | Add jvm/android to catalog + tree          |
| `docs/extending.md`                | Modify | Add JVM/Android usage examples             |
| `AGENTS.md`                        | Modify | Update inheritance tree + directory layout |

---

## Task 1: Create `:jvm-debian` Dockerfile

**Files:**

- Create: `images/jvm/Dockerfile.debian`

- [ ] **Step 1: Create the image directory**

```bash
mkdir -p images/jvm
```

- [ ] **Step 2: Write the Dockerfile**

Create `images/jvm/Dockerfile.debian`:

```dockerfile
# syntax=docker/dockerfile:1
# hadolint ignore=DL3006
FROM dock-core

ARG VERSION=dev
# Install JDK 17 headless (ca-certificates-java hooks into
# update-ca-certificates to auto-populate the JKS truststore).
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
    openjdk-17-jdk-headless \
 && rm -rf /var/lib/apt/lists/*

# Set JAVA_HOME using dpkg architecture (amd64, arm64).
# The Debian JDK directory is architecture-specific.
RUN ARCH="$(dpkg --print-architecture)" \
 && echo "JAVA_HOME=/usr/lib/jvm/java-17-openjdk-${ARCH}" \
      >> /etc/environment
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
# Overridden at runtime via /etc/environment on arm64 — but ENV
# is baked per-platform during multi-arch builds, so BuildKit
# resolves the correct value. Use a RUN step instead:
```

**Wait — the ENV approach won't work for multi-arch.** Revised:

```dockerfile
# syntax=docker/dockerfile:1
# hadolint ignore=DL3006
FROM dock-core

ARG VERSION=dev
# Install JDK 17 headless (ca-certificates-java hooks into
# update-ca-certificates to auto-populate the JKS truststore).
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
    openjdk-17-jdk-headless \
 && rm -rf /var/lib/apt/lists/*

# Resolve JAVA_HOME for the build platform and persist it.
# Debian names the directory java-17-openjdk-<dpkg-arch>.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN ARCH="$(dpkg --print-architecture)" \
 && JAVA_HOME="/usr/lib/jvm/java-17-openjdk-${ARCH}" \
 && printf 'export JAVA_HOME=%s\nexport PATH=%s/bin:$PATH\n' \
      "$JAVA_HOME" "$JAVA_HOME" > /etc/profile.d/java.sh \
 && chmod +x /etc/profile.d/java.sh \
 && ln -s "$JAVA_HOME" /usr/lib/jvm/java-17-openjdk

# Use the symlink for ENV so it works on all architectures.
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk
ENV PATH="${JAVA_HOME}/bin:${PATH}"

# Generate manifest
COPY scripts/manifest.sh /usr/local/bin/manifest.sh
RUN manifest.sh jvm "${VERSION}"
```

- [ ] **Step 3: Verify Dockerfile passes hadolint**

```bash
hadolint images/jvm/Dockerfile.debian
```

Expected: no output (zero warnings).

- [ ] **Step 4: Commit**

```bash
git add images/jvm/Dockerfile.debian
git commit -m "feat: add jvm-debian Dockerfile with JDK 17 headless"
```

---

## Task 2: Create `:android-debian` Dockerfile

**Files:**

- Create: `images/android/Dockerfile.debian`

- [ ] **Step 1: Create the image directory**

```bash
mkdir -p images/android
```

- [ ] **Step 2: Write the Dockerfile**

Create `images/android/Dockerfile.debian`:

```dockerfile
# syntax=docker/dockerfile:1
# hadolint ignore=DL3006
FROM dock-jvm

ARG VERSION=dev
ARG ANDROID_CMDLINE_TOOLS_VERSION=14742923
ARG ANDROID_BUILD_TOOLS_VERSION=36.1.0
ARG ANDROID_PLATFORM_VERSION=36

ENV ANDROID_HOME=/opt/android-sdk \
    ANDROID_SDK_ROOT=/opt/android-sdk

ENV PATH="${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${PATH}"

# Download and install Android SDK command-line tools.
# hadolint ignore=DL3003
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN mkdir -p "${ANDROID_HOME}/cmdline-tools" \
 && curl -sSfL \
      "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_VERSION}_latest.zip" \
      -o /tmp/cmdline-tools.zip \
 && unzip -q /tmp/cmdline-tools.zip -d /tmp/cmdline-tools \
 && mv /tmp/cmdline-tools/cmdline-tools "${ANDROID_HOME}/cmdline-tools/latest" \
 && rm -rf /tmp/cmdline-tools.zip /tmp/cmdline-tools

# Accept licenses and install SDK components.
RUN yes | sdkmanager --licenses > /dev/null 2>&1 \
 && sdkmanager --install \
      "platform-tools" \
      "build-tools;${ANDROID_BUILD_TOOLS_VERSION}" \
      "platforms;android-${ANDROID_PLATFORM_VERSION}"

# Generate manifest
COPY scripts/manifest.sh /usr/local/bin/manifest.sh
RUN manifest.sh android "${VERSION}"
```

- [ ] **Step 3: Verify Dockerfile passes hadolint**

```bash
hadolint images/android/Dockerfile.debian
```

Expected: no output (zero warnings).

- [ ] **Step 4: Commit**

```bash
git add images/android/Dockerfile.debian
git commit -m "feat: add android-debian Dockerfile with SDK cmdline-tools"
```

---

## Task 3: Add build targets to `docker-bake.hcl`

**Files:**

- Modify: `docker-bake.hcl`

- [ ] **Step 1: Add `jvm-debian` target**

Add after the `polyglot-debian` target block (before the Groups
section):

```hcl
target "jvm-debian" {
  inherits   = ["_common", "_cache-debian"]
  context    = "."
  dockerfile = "images/jvm/Dockerfile.debian"
  tags = [
    "${REGISTRY}:jvm-debian-${VERSION}${PLATFORM_SUFFIX}", "${REGISTRY}:jvm-debian${PLATFORM_SUFFIX}",
    "${REGISTRY_DH}:jvm-debian-${VERSION}${PLATFORM_SUFFIX}", "${REGISTRY_DH}:jvm-debian${PLATFORM_SUFFIX}",
  ]
  contexts = { dock-core = "target:core-debian" }
}
```

- [ ] **Step 2: Add `android-debian` target**

Add immediately after the `jvm-debian` target:

```hcl
target "android-debian" {
  inherits   = ["_common", "_cache-debian"]
  context    = "."
  dockerfile = "images/android/Dockerfile.debian"
  tags = [
    "${REGISTRY}:android-debian-${VERSION}${PLATFORM_SUFFIX}", "${REGISTRY}:android-debian${PLATFORM_SUFFIX}",
    "${REGISTRY_DH}:android-debian-${VERSION}${PLATFORM_SUFFIX}", "${REGISTRY_DH}:android-debian${PLATFORM_SUFFIX}",
  ]
  contexts = { dock-jvm = "target:jvm-debian" }
}
```

- [ ] **Step 3: Add both to the `debian` group**

Update the `debian` group to include the new targets:

```hcl
group "debian" {
  targets = [
    "core-debian",
    "rust-debian",
    "deno-debian",
    "node-debian",
    "python-debian",
    "polyglot-debian",
    "jvm-debian",
    "android-debian",
  ]
}
```

- [ ] **Step 4: Verify bake file parses**

```bash
docker buildx bake --print 2>&1 | head -5
```

Expected: JSON output (no parse errors).

- [ ] **Step 5: Commit**

```bash
git add docker-bake.hcl
git commit -m "feat: add jvm-debian and android-debian bake targets"
```

---

## Task 4: Add test runner entries for JVM and Android

**Files:**

- Modify: `tests/run.sh`

- [ ] **Step 1: Add JVM and Android to the TEST_SCRIPTS map**

In `tests/run.sh`, add to the `declare -A TEST_SCRIPTS` block
(after the `[polyglot-debian]` entry):

```bash
[jvm-debian]="test_jvm.sh"
[android-debian]="test_android.sh"
```

- [ ] **Step 2: Commit**

```bash
git add tests/run.sh
git commit -m "chore: add jvm-debian and android-debian to test runner"
```

---

## Task 5: Write JVM tests

**Files:**

- Create: `tests/test_jvm.sh`

- [ ] **Step 1: Write the test file**

Create `tests/test_jvm.sh`:

```bash
#!/usr/bin/env bash
# JVM tests — presence + sanity for the :jvm-debian image.
# Sources test_core.sh so all core tests also run.

# shellcheck source=tests/test_core.sh
source "$(dirname "$0")/test_core.sh"

# ---------------------------------------------------------------------------
# Presence tests
# ---------------------------------------------------------------------------

test_java_present()    { assert "command -v java"; }
test_javac_present()   { assert "command -v javac"; }
test_keytool_present() { assert "command -v keytool"; }

# ---------------------------------------------------------------------------
# Sanity tests
# ---------------------------------------------------------------------------

test_java_version() {
  assert "java -version 2>&1 | grep -q 'openjdk version \"17\\.'"
}

test_javac_version() {
  assert "javac -version"
}

test_java_home_set() {
  assert "[ -n \"$JAVA_HOME\" ]"
}

test_java_home_valid_dir() {
  assert "[ -d \"$JAVA_HOME\" ]"
}

test_jks_truststore_exists() {
  assert "[ -f \"${JAVA_HOME}/lib/security/cacerts\" ]"
}
```

- [ ] **Step 2: Verify shellcheck passes**

```bash
shellcheck tests/test_jvm.sh
```

Expected: no output (zero warnings).

- [ ] **Step 3: Commit**

```bash
git add tests/test_jvm.sh
git commit -m "test: add jvm-debian presence and sanity tests"
```

---

## Task 6: Write Android tests

**Files:**

- Create: `tests/test_android.sh`

- [ ] **Step 1: Write the test file**

Create `tests/test_android.sh`:

```bash
#!/usr/bin/env bash
# Android tests — presence + sanity for the :android-debian image.
# Sources test_jvm.sh so all JVM + core tests also run.

# shellcheck source=tests/test_jvm.sh
source "$(dirname "$0")/test_jvm.sh"

# ---------------------------------------------------------------------------
# Presence tests
# ---------------------------------------------------------------------------

test_sdkmanager_present() { assert "command -v sdkmanager"; }
test_aapt2_present() {
  # aapt2 lives inside build-tools, not on PATH by default.
  # Verify it exists inside ANDROID_HOME.
  assert "find \"$ANDROID_HOME\" -name aapt2 -type f | grep -q aapt2"
}

# ---------------------------------------------------------------------------
# Sanity tests
# ---------------------------------------------------------------------------

test_sdkmanager_list() {
  assert "sdkmanager --list 2>&1 | grep -q 'build-tools'"
}

test_aapt2_version() {
  local aapt2
  aapt2="$(find "$ANDROID_HOME" -name aapt2 -type f | head -1)"
  assert "\"$aapt2\" version"
}

test_android_home_set() {
  assert "[ -n \"$ANDROID_HOME\" ]"
}

test_android_home_valid_dir() {
  assert "[ -d \"$ANDROID_HOME\" ]"
}

test_android_sdk_root_set() {
  assert "[ -n \"$ANDROID_SDK_ROOT\" ]"
}
```

- [ ] **Step 2: Verify shellcheck passes**

```bash
shellcheck tests/test_android.sh
```

Expected: no output (zero warnings).

- [ ] **Step 3: Commit**

```bash
git add tests/test_android.sh
git commit -m "test: add android-debian presence and sanity tests"
```

---

## Task 7: Extend `dock-bootstrap` with JKS truststore support

**Files:**

- Modify: `scripts/dock-bootstrap.sh`

- [ ] **Step 1: Add JKS import function after the read-only
      fallback section**

At the end of `scripts/dock-bootstrap.sh`, just before the final
`echo` on the read-only fallback path, add JKS handling. The full
change is to insert a new section **after** the `ca.env` file is
written (inside the read-only fallback branch), and also **after**
the happy-path `update-ca-certificates` success.

Replace the current exit-0 after successful `update-ca-certificates`
and the final echo of the read-only path with JKS-aware versions.

Find the line:

```sh
if update-ca-certificates 2>/dev/null; then
  echo "dock-bootstrap: imported $COUNT certificate source(s) into trust store"
  exit 0
fi
```

Replace with:

```sh
if update-ca-certificates 2>/dev/null; then
  echo "dock-bootstrap: imported $COUNT certificate source(s) into trust store"
  # JKS truststore is auto-updated by ca-certificates-java hook
  # when update-ca-certificates succeeds — no extra work needed.
  exit 0
fi
```

Then, at the very end of the file (after the `ca.env` cat block),
add:

```sh
# -------------------------------------------------------------------------
# 5. JKS truststore fallback (JVM images on read-only K8s runners)
# -------------------------------------------------------------------------
# When the system trust store is read-only, update-ca-certificates
# cannot run the ca-certificates-java hook. Copy the JKS truststore
# to a writable location and import the PEM certs via keytool.
if command -v keytool >/dev/null 2>&1 && [ -n "${JAVA_HOME:-}" ]; then
  JKS_SRC="${JAVA_HOME}/lib/security/cacerts"
  JKS_DST="/etc/dock/cacerts"
  if [ -f "$JKS_SRC" ]; then
    cp "$JKS_SRC" "$JKS_DST"
    # Import each PEM cert into the writable JKS copy.
    for f in "$DEST"/*.crt; do
      [ -f "$f" ] || continue
      alias="dock-$(basename "$f" .crt)"
      keytool -importcert -noprompt -trustcacerts \
        -keystore "$JKS_DST" -storepass changeit \
        -alias "$alias" -file "$f" 2>/dev/null || true
    done
    # Append JAVA_TOOL_OPTIONS to ca.env so JVM tools use the
    # updated truststore.
    printf 'export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:-} -Djavax.net.ssl.trustStore=%s"\n' \
      "$JKS_DST" >> "$DOCK_ENV"
    echo "dock-bootstrap: updated JKS truststore at $JKS_DST"
  fi
fi

echo "dock-bootstrap: imported $COUNT certificate source(s) (read-only trust store, using $DOCK_BUNDLE)"
echo "dock-bootstrap: source $DOCK_ENV to apply" >&2
```

And **remove** the existing final two echo lines (they are now
included at the end of the JKS block above).

- [ ] **Step 2: Verify shellcheck passes**

```bash
shellcheck scripts/dock-bootstrap.sh
```

Expected: no output (zero warnings).

- [ ] **Step 3: Commit**

```bash
git add scripts/dock-bootstrap.sh
git commit -m "feat: extend dock-bootstrap with JKS truststore fallback for JVM images"
```

---

## Task 8: Build and test locally

**Files:** None (verification only)

- [ ] **Step 1: Build the JVM image**

```bash
docker buildx bake jvm-debian
```

Expected: build succeeds.

- [ ] **Step 2: Build the Android image**

```bash
docker buildx bake android-debian
```

Expected: build succeeds.

- [ ] **Step 3: Run JVM tests**

```bash
bash tests/run.sh jvm-debian
```

Expected: all tests pass.

- [ ] **Step 4: Run Android tests**

```bash
bash tests/run.sh android-debian
```

Expected: all tests pass.

- [ ] **Step 5: Run lint**

```bash
just lint
```

Expected: zero warnings.

---

## Task 9: Update documentation

**Files:**

- Modify: `README.md`
- Modify: `docs/extending.md`
- Modify: `AGENTS.md`

- [ ] **Step 1: Update `README.md` — image catalog table**

In the "Available images" table, add two rows before the `:lint`
row (or at the end — `:lint` is not currently in the table):

```markdown
| `:jvm` | `:core` | — | JDK 17 headless (Debian only) |
| `:android` | `:jvm` | — | Android SDK cmdline-tools, build-tools, platform SDK (Debian only) |
```

- [ ] **Step 2: Update `README.md` — inheritance tree**

Add the JVM/Android branch to the tree. The tree currently shows
Alpine only; add a Debian section or a note. Since jvm/android are
Debian-only, add after the existing tree:

```markdown
debian:bookworm-slim (Debian variants — `-debian` suffix)
└── :core-debian (~90 MB)
├── :rust-debian (~320 MB)
│ └── :polyglot-debian (~450 MB)
├── :deno-debian (~170 MB)
├── :node-debian (~165 MB)
├── :python-debian (~105 MB)
└── :jvm-debian (~290 MB)
└── :android-debian (~485 MB)
```

- [ ] **Step 3: Update `docs/extending.md` — JVM/Android examples**

Add a new section "## Using the JVM image" after the "Adding a
Cargo tool" section:

````markdown
## Using the JVM image

The `:jvm-debian` image includes JDK 17 headless. Projects using
Gradle should rely on the Gradle Wrapper (`./gradlew`), which
downloads the correct Gradle version automatically:

```yaml
# GitLab CI
build:
  image: ghcr.io/driftsys/dock:jvm-debian
  before_script:
    - dock-bootstrap
    - . /etc/dock/ca.env 2>/dev/null || true
  script:
    - ./gradlew build
```
````

## Using the Android image

The `:android-debian` image includes JDK 17, Android SDK
command-line tools, build-tools 36.1.0, and platform SDK
android-36. Install additional platform SDKs at CI time if
your project targets older API levels:

```yaml
# GitLab CI
android-build:
  image: ghcr.io/driftsys/dock:android-debian
  before_script:
    - dock-bootstrap
    - . /etc/dock/ca.env 2>/dev/null || true
    - sdkmanager "platforms;android-34" "platforms;android-35"
  script:
    - ./gradlew assembleDebug
```

```yaml
# GitHub Actions
jobs:
  build:
    runs-on: ubuntu-latest
    container: ghcr.io/driftsys/dock:android-debian
    steps:
      - run: |
          dock-bootstrap
          . /etc/dock/ca.env 2>/dev/null || true
      - uses: actions/checkout@v4
      - run: ./gradlew assembleDebug
```

````
- [ ] **Step 4: Update `AGENTS.md` — inheritance tree**

Replace the inheritance tree in AGENTS.md with:

```text
alpine:3.21
  └── :core              (~32 MB)
      ├── :lint          (~44 MB)   [low prio]
      ├── :rust          (~260 MB)
      │   └── :polyglot  (~382 MB)
      ├── :deno          (~120 MB)
      ├── :node          (~115 MB)
      └── :python        (~55 MB)

debian:bookworm-slim (Debian-only images)
  └── :core-debian
      └── :jvm-debian    (~290 MB)
          └── :android-debian (~485 MB)
````

- [ ] **Step 5: Update `AGENTS.md` — directory layout**

Add `jvm/` and `android/` to the directory layout:

```text
dock/
├── images/
│   ├── core/
│   ├── rust/
│   ├── deno/
│   ├── node/
│   ├── python/
│   ├── polyglot/
│   ├── jvm/
│   └── android/
├── tests/
│   └── fixtures/ca/
├── scripts/
│   └── dock-bootstrap.sh
└── docs/
```

- [ ] **Step 6: Commit**

```bash
git add README.md docs/extending.md AGENTS.md
git commit -m "docs: add jvm and android images to documentation"
```

---

## Task 10: Squash into a single commit

Per AGENTS.md convention ("One commit per PR"), squash all
work into a single commit before opening the PR.

- [ ] **Step 1: Interactive rebase to squash**

Count the commits from this branch:

```bash
git log --oneline main..HEAD
```

Then squash:

```bash
git rebase -i main
```

Mark all commits except the first as `squash`. Use this final
message:

```
feat: add jvm-debian and android-debian images

Add two new Debian-only Docker images:

- :jvm-debian — JDK 17 headless on core-debian (~290 MB)
- :android-debian — Android SDK on jvm-debian (~485 MB)

Includes Dockerfiles, docker-bake targets, bash_unit tests,
dock-bootstrap JKS truststore fallback for read-only K8s
runners, and documentation updates.
```

- [ ] **Step 2: Final verification**

```bash
just lint
```

Expected: zero warnings.

---

## Spec Coverage Review

| Spec requirement                           | Task                       |
| ------------------------------------------ | -------------------------- |
| `images/jvm/Dockerfile.debian`             | Task 1                     |
| `images/android/Dockerfile.debian`         | Task 2                     |
| `docker-bake.hcl` targets + group          | Task 3                     |
| `tests/test_jvm.sh`                        | Task 5                     |
| `tests/test_android.sh`                    | Task 6                     |
| `scripts/dock-bootstrap.sh` JKS support    | Task 7                     |
| `tests/run.sh` test matrix                 | Task 4                     |
| `README.md` image catalog                  | Task 9                     |
| `docs/extending.md` usage examples         | Task 9                     |
| `AGENTS.md` tree + layout                  | Task 9                     |
| JAVA_HOME multi-arch resolution            | Task 1 (symlink approach)  |
| CA trust normal + read-only paths          | Task 7                     |
| Android SDK version pinning via build args | Task 2                     |
| License acceptance                         | Task 2                     |
| No Alpine variant                          | ✓ (Debian only throughout) |
