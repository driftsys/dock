# Versioning strategy

## Tag format

```
ghcr.io/driftsys/dock:{image}-{variant}-{version}
```

- `{image}` — `core`, `rust`, `deno`, `node`, `python`, `polyglot`
- `{variant}` — omitted for Alpine (default); `-debian` for the Debian variant
- `{version}` — semantic version tag, e.g. `v1.2.3`

### Examples

```
ghcr.io/driftsys/dock:core           # latest Alpine core
ghcr.io/driftsys/dock:core-v1.2.3   # pinned Alpine core
ghcr.io/driftsys/dock:rust-debian    # latest Debian rust
```

## Floating tags

Floating tags (`:core`, `:rust`, …) always point to the latest release.
Use them in prototyping; pin to a version tag in production.

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

## Rebuild strategy

Images are rebuilt on every release tag (`v*`). The OS base
(`alpine:3.21`, `debian:bookworm-slim`) is resolved at build time. All
installed packages reflect the state of the package index at release time.

Security patches to the base OS are incorporated by cutting a new release.
Dependabot is configured to notify when referenced base images have known
CVEs.
