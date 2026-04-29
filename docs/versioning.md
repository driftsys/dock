# Versioning strategy

## Tag format

```
ghcr.io/driftsys/dock:{image}-{variant}-{version}
```

- `{image}` — `core`, `rust`, `deno`, `node`, `python`, `polyglot`,
  `jvm`, `android`
- `{variant}` — omitted for Alpine (default); `-debian` for the Debian variant
- `{version}` — semantic version tag, e.g. `v1.2.3`

### Examples

```
ghcr.io/driftsys/dock:core           # latest Alpine core
ghcr.io/driftsys/dock:core-v1.2.3   # pinned Alpine core
ghcr.io/driftsys/dock:rust-debian    # latest Debian rust
ghcr.io/driftsys/dock:android-36-debian  # pinned to API 36
```

## Floating tags

Floating tags (`:core`, `:rust`, …) always point to the latest release.
Use them in prototyping; pin to a version tag in production.

## Android API-level tags

The `:android` image publishes an additional pinned tag per API
level:

- `:android-debian` — floating, always current stable API
- `:android-36-debian` — pinned to API 36

When the API level is bumped (e.g., to 37), the old pinned tag
remains in the registry but stops receiving updates (deprecated).

## Semantic versioning

Releases follow [Semantic Versioning](https://semver.org):

| Change                                      | Bump  |
| ------------------------------------------- | ----- |
| Breaking change (tool removed, API changed) | major |
| New tool added, runtime upgrade             | minor |
| Bug fix, security patch                     | patch |

## Runtime pinning

Runtime versions are recorded in `/etc/dock/manifest.json` inside each
image — not in the image tag. Inspect them with:

```bash
docker run --rm ghcr.io/driftsys/dock:rust \
  jq . /etc/dock/manifest.json
```

To pin a specific runtime version, use the `--build-arg` override at build
time (see [extending.md](extending.md)).

## SDK and runtime update cadence

Different runtimes follow different upstream release schedules. The
table below summarizes the update policy for each:

| Runtime         | Update trigger                   | Frequency  |
| --------------- | -------------------------------- | ---------- |
| Alpine / Debian | New base image tag               | As needed  |
| Rust            | New stable release               | ~6 weeks   |
| Deno            | New stable release               | ~4 weeks   |
| Node.js         | New LTS release                  | ~12 months |
| Python          | New stable release               | ~12 months |
| JDK             | New LTS release (17 → 21 → …)    | ~2 years   |
| Android SDK     | New stable API level from Google | ~12 months |

**Android SDK specifics:** The `:android-debian` image ships the latest
stable API level only (no beta/preview). Google Play Store requires
apps to target the latest stable SDK within ~1 year of release, so the
image tracks that requirement. Bumps are manual — watch the
[platform releases page](https://developer.android.com/tools/releases/platforms).

**JDK specifics:** The `:jvm-debian` image tracks the current LTS
release (currently JDK 17). Migration to the next LTS (JDK 21) will
be a minor version bump with advance notice in the changelog.

## Rebuild strategy

Images are rebuilt on every release tag (`v*`). The OS base
(`alpine:3.21`, `debian:bookworm-slim`) is resolved at build time. All
installed packages reflect the state of the package index at release time.

Security patches to the base OS are incorporated by cutting a new release.
Dependabot is configured to notify when referenced base images have known
CVEs.
