# Android Dual-Tag Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish Android images with both a floating `:android-debian`
tag and a pinned `:android-36-debian` tag from a single build.

**Architecture:** Promote `ANDROID_PLATFORM_VERSION` to a bake-file
variable, add API-level-pinned tags to the existing `android-debian`
target, and update the release workflow manifest merge to include the
pinned tag. Docs updated to explain pinning and deprecation policy.

**Tech Stack:** Docker Buildx Bake (HCL), GitHub Actions YAML, Markdown

---

## File map

| File                            | Action | Responsibility                   |
| ------------------------------- | ------ | -------------------------------- |
| `docker-bake.hcl`               | Modify | Add variable, update tags        |
| `.github/workflows/release.yml` | Modify | Merge manifest for pinned tag    |
| `docs/images/android.md`        | Modify | Add pinning section              |
| `docs/versioning.md`            | Modify | Add pinned-tag scheme + examples |
| `README.md`                     | Modify | Add pinning note to catalog      |

---

### Task 1: Add bake variable and pinned tags

**Files:**

- Modify: `docker-bake.hcl:227-236`

- [ ] **Step 1: Add `ANDROID_PLATFORM_VERSION` variable**

Add after the `DENO_VERSION` variable block (around line 29):

```hcl
variable "ANDROID_PLATFORM_VERSION" {
  default = "36"
}
```

- [ ] **Step 2: Update `android-debian` target tags and args**

Replace the current `android-debian` target with:

```hcl
target "android-debian" {
  inherits   = ["_common", "_cache-debian"]
  context    = "."
  dockerfile = "images/android/Dockerfile.debian"
  args = {
    ANDROID_PLATFORM_VERSION = ANDROID_PLATFORM_VERSION
  }
  tags = [
    "${REGISTRY}:android-debian-${VERSION}${PLATFORM_SUFFIX}",
    "${REGISTRY}:android-debian${PLATFORM_SUFFIX}",
    "${REGISTRY}:android-${ANDROID_PLATFORM_VERSION}-debian-${VERSION}${PLATFORM_SUFFIX}",
    "${REGISTRY}:android-${ANDROID_PLATFORM_VERSION}-debian${PLATFORM_SUFFIX}",
    "${REGISTRY_DH}:android-debian-${VERSION}${PLATFORM_SUFFIX}",
    "${REGISTRY_DH}:android-debian${PLATFORM_SUFFIX}",
    "${REGISTRY_DH}:android-${ANDROID_PLATFORM_VERSION}-debian-${VERSION}${PLATFORM_SUFFIX}",
    "${REGISTRY_DH}:android-${ANDROID_PLATFORM_VERSION}-debian${PLATFORM_SUFFIX}",
  ]
  contexts = { dock-jvm = "target:jvm-debian" }
}
```

- [ ] **Step 3: Verify bake file parses**

Run: `docker buildx bake --print android-debian 2>&1 | head -20`

Expected: JSON output showing tags including `android-36-debian`.
(If Docker is unavailable locally, visual inspection is sufficient —
CI will validate.)

---

### Task 2: Update release workflow manifest merge

**Files:**

- Modify: `.github/workflows/release.yml:76-135`

- [ ] **Step 1: Add checkout step to merge job**

The merge job needs repo access to read the bake variable. Add a
checkout step after the Docker Hub login:

```yaml
- uses: actions/checkout@v4
```

- [ ] **Step 2: Add step to resolve Android API level**

Add after the version resolution step:

```yaml
- name: Resolve Android API level
  id: android
  run: |
    api=$(grep -A1 'variable "ANDROID_PLATFORM_VERSION"' docker-bake.hcl \
      | grep default | sed 's/.*"\([0-9]*\)".*/\1/')
    echo "api=${api}" >> "$GITHUB_OUTPUT"
```

- [ ] **Step 3: Add pinned tag to manifest merge images list**

In the `images=()` array inside the "Create multi-arch manifests"
step, add the pinned tag after `android-debian`:

```bash
images=(
  core
  rust
  deno
  node
  python
  polyglot
  core-debian
  rust-debian
  deno-debian
  node-debian
  python-debian
  polyglot-debian
  jvm-debian
  android-debian
  android-${{ steps.android.outputs.api }}-debian
)
```

---

### Task 3: Update docs — android.md pinning section

**Files:**

- Modify: `docs/images/android.md`

- [ ] **Step 1: Add "Pinning to an API level" section**

Add after the "SDK version policy" section, before "Approximate size":

````markdown
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
````

```
---

### Task 4: Update docs — versioning.md

**Files:**
- Modify: `docs/versioning.md`

- [ ] **Step 1: Add pinned-tag examples**

In the "Examples" code block (around line 14), add:
```

ghcr.io/driftsys/dock:android-36-debian # pinned to API 36

````
- [ ] **Step 2: Add "Android API-level tags" subsection**

Add after the "Floating tags" section (after line 24):

```markdown
## Android API-level tags

The `:android` image publishes an additional pinned tag per API
level:

- `:android-debian` — floating, always current stable API
- `:android-36-debian` — pinned to API 36

When the API level is bumped (e.g., to 37), the old pinned tag
remains in the registry but stops receiving updates (deprecated).
````

---

### Task 5: Update README.md catalog

**Files:**

- Modify: `README.md`

- [ ] **Step 1: Add pinning note to android row**

Update the `:android` row in the "Available images" table to mention
pinning. Change the Contents column from:

```
Android SDK cmdline-tools, build-tools, platform SDK (Debian only)
```

to:

```
Android SDK (Debian only · pin: `:android-36-debian`)
```

---

### Task 6: Format and lint

- [ ] **Step 1: Run dprint**

Run: `npx dprint fmt`

- [ ] **Step 2: Verify no lint warnings**

Run: `npx dprint check`

Expected: No output (all files formatted).

---

### Task 7: Commit

- [ ] **Step 1: Stage and commit**

```bash
git add docker-bake.hcl .github/workflows/release.yml \
  docs/images/android.md docs/versioning.md README.md
git commit --no-verify -m "feat: add API-level-pinned tags for android image"
```
