# Android dual-tag design

## Problem

Users need to pin to a specific Android API level while still being
able to use a floating "latest" tag. When we bump from API 36 to 37,
users who haven't migrated yet should still be able to reference API
36 by tag — but we don't want the maintenance burden of rebuilding
old API levels indefinitely.

## Solution

Publish **two tags** from a single build:

- `:android-debian` — floating, always the current stable API level
- `:android-{API}-debian` — pinned to the API level at build time

When we bump to a new API level, the old pinned tag stays in the
registry as-is (deprecated, no longer rebuilt). Users get a migration
window but accept that the old tag won't receive security patches.

## Tag scheme

### During API 36 era

| Tag                        | Points to    | Updated?      |
| -------------------------- | ------------ | ------------- |
| `:android-debian`          | API 36 build | Every release |
| `:android-debian-0.1.9`    | API 36 build | Immutable     |
| `:android-36-debian`       | API 36 build | Every release |
| `:android-36-debian-0.1.9` | API 36 build | Immutable     |

### After bump to API 37

| Tag                  | Points to         | Updated?            |
| -------------------- | ----------------- | ------------------- |
| `:android-debian`    | API 37 build      | Every release       |
| `:android-37-debian` | API 37 build      | Every release       |
| `:android-36-debian` | Last API 36 build | Frozen (deprecated) |

## Implementation

### 1. Bake file (`docker-bake.hcl`)

Add a top-level variable for the Android platform version (already
exists as a Dockerfile ARG, promote to bake variable):

```hcl
variable "ANDROID_PLATFORM_VERSION" {
  default = "36"
}
```

Update the `android-debian` target to include pinned tags and pass
the version as a build arg:

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

No new targets. No groups change. The single build produces both
tag families.

### 2. Release workflow (`.github/workflows/release.yml`)

The merge manifest step must create multi-arch manifests for the
pinned tag in addition to the floating tag. Add
`android-${ANDROID_PLATFORM_VERSION}-debian` to the images list.

Since the platform version is a bake variable (not directly available
in the workflow), extract it at the top of the merge job:

```yaml
- name: Resolve Android API level
  id: android
  run: |
    # Read from docker-bake.hcl
    api=$(grep -A1 'variable "ANDROID_PLATFORM_VERSION"' docker-bake.hcl \
      | grep default | sed 's/.*"\([0-9]*\)".*/\1/')
    echo "api=${api}" >> "$GITHUB_OUTPUT"
```

Then in the manifest merge loop, include both:

```yaml
images=(
  ...
  android-debian
  android-${{ steps.android.outputs.api }}-debian
)
```

Both tags reference the same per-arch digests — zero extra build
time.

### 3. CI workflow (`.github/workflows/ci.yml`)

No changes needed. The `detect` job already maps
`images/android/` → `android-debian`. The bake target name hasn't
changed. Tests run against `android-debian` which is the same image
that gets the pinned tag.

### 4. Tests

No changes. `tests/test_android.sh` tests the image regardless of
what tag it was pushed with.

### 5. Docs updates

**`docs/images/android.md`:**

- Add "Pinning" section explaining the dual-tag scheme
- Add example: `ghcr.io/driftsys/dock:android-36-debian`
- Document deprecation policy (old tags frozen, not rebuilt)

**`docs/versioning.md`:**

- Add Android pinned-tag scheme to the tag format section
- Mention deprecation policy

**`README.md`:**

- Add note in catalog table that android supports API-level pinning

## Bumping to a new API level (future procedure)

Single PR:

1. Update `ANDROID_PLATFORM_VERSION` default in `docker-bake.hcl`
   from `"36"` to `"37"`
2. Update `ANDROID_BUILD_TOOLS_VERSION` if needed
3. Update `ANDROID_CMDLINE_TOOLS_VERSION` if needed
4. Update test assertions in `tests/test_android.sh`
5. Update docs (`android.md` current baseline, examples)
6. Cut release — the old `:android-36-debian` tag stays in registry

## Removing a deprecated tag (optional, future)

Old tags live in the registry indefinitely (storage is cheap). If
cleanup is desired, use `gh api` to delete the package version from
GHCR. This is a manual operation, not automated.

## Scope exclusions

- **No multi-version concurrent builds** — only one API level is
  built per release
- **No security patches to old tags** — deprecated means frozen
- **No JVM dual tags** — JVM stays as `:jvm-debian` only
- **No selective release** — all images rebuild on every release (as
  today)
