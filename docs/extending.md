# Extending dock images

All `dock` images are toolboxes with no `CMD` or `ENTRYPOINT`. Adding
packages on top is straightforward.

## Adding an apk package (Alpine)

```dockerfile
FROM ghcr.io/driftsys/dock:core

# hadolint ignore=DL3018
RUN apk add --no-cache sqlite
```

## Adding an apt package (Debian)

```dockerfile
FROM ghcr.io/driftsys/dock:core-debian

# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends sqlite3 \
 && rm -rf /var/lib/apt/lists/*
```

## Adding a Cargo tool (on top of :rust)

```dockerfile
FROM ghcr.io/driftsys/dock:rust

RUN cargo install cargo-nextest --locked
```

## Pinning a runtime version

All runtime images accept build arguments for version pinning:

```bash
# Build a Deno image with a specific version
docker buildx build \
  --build-arg DENO_VERSION=2.0.0 \
  -f images/deno/Dockerfile .
```

## Multi-stage builds

Use `dock` images in the build stage; copy artifacts to a minimal final
image:

```dockerfile
FROM ghcr.io/driftsys/dock:rust AS builder
WORKDIR /src
COPY . .
RUN cargo build --release

FROM alpine:3.21
COPY --from=builder /src/target/release/myapp /usr/local/bin/
```

## Corporate environments

### CA certificates with `dock-bootstrap`

If your CI runners provide corporate CA certificates (as environment
variables, files, or via GitLab's `CI_SERVER_TLS_CA_FILE`),
`dock-bootstrap` detects and imports them into the system trust store
automatically:

```yaml
# GitLab CI — add to your pipeline
default:
  before_script:
    - dock-bootstrap
```

That's it. `dock-bootstrap` scans three sources:

1. **Environment variables** — any env var containing a PEM
   certificate (`-----BEGIN CERTIFICATE-----`) is detected and
   imported. This works with GitLab group/instance CI/CD variables
   that contain CA certificates.
2. **Drop directory** — `.crt` and `.pem` files in `/etc/dock/ca.d/`
   (or a custom path passed as `$1`).
3. **`CI_SERVER_TLS_CA_FILE`** — the GitLab runner-provided CA file,
   if present.

All dock images pre-set `SSL_CERT_FILE`, `CURL_CA_BUNDLE`,
`GIT_SSL_CAINFO`, and language-specific variables
(`CARGO_HTTP_CAINFO`, `NODE_EXTRA_CA_CERTS`, `DENO_CERT`, `PIP_CERT`)
to point at `/etc/ssl/certs/ca-certificates.crt` — the file
`update-ca-certificates` populates. Every tool picks up custom CAs
without further configuration.

To skip CA detection (e.g. in jobs that don't need it):

```yaml
variables:
  DOCK_SKIP_CA: "1"
```

### Fetching CA certificates at CI build time

If you need CAs at Docker **build** time (not just runtime), fetch
them from a central store in your CI pipeline rather than committing
them to git:

```yaml
build:
  before_script:
    - curl -sSf https://artifactory.corp/certs/ca-bundle.tar.gz
        -o ca-bundle.tar.gz
    - mkdir -p corp-certs && tar -xzf ca-bundle.tar.gz -C corp-certs
  script:
    - docker build -t my-ci-image .
```

```dockerfile
FROM ghcr.io/driftsys/dock:rust
COPY corp-certs/ /etc/dock/ca.d/
RUN dock-bootstrap
```

### Build-time HTTP proxy

Docker's built-in predefined build args handle proxy pass-through —
no Dockerfile changes needed:

```bash
docker build \
  --build-arg HTTP_PROXY=http://proxy.corp:3128 \
  --build-arg HTTPS_PROXY=http://proxy.corp:3128 \
  --build-arg NO_PROXY=.corp.internal,10.0.0.0/8 \
  -t my-ci-image .
```

In **GitLab CI**:

```yaml
build:
  variables:
    HTTP_PROXY: http://proxy.corp:3128
    HTTPS_PROXY: http://proxy.corp:3128
    NO_PROXY: .corp.internal
  script:
    - docker build
        --build-arg HTTP_PROXY
        --build-arg HTTPS_PROXY
        --build-arg NO_PROXY
        -t my-ci-image .
```

In **GitHub Actions**:

```yaml
- name: Build
  run: |
    docker build \
      --build-arg HTTP_PROXY=${{ vars.HTTP_PROXY }} \
      --build-arg HTTPS_PROXY=${{ vars.HTTPS_PROXY }} \
      --build-arg NO_PROXY=${{ vars.NO_PROXY }} \
      -t my-ci-image .
```

Note: these affect **build time** only. For runtime proxy, set the
variables via `docker run -e` or your orchestrator's environment
configuration.

### Why no `-corp` variant?

Corporate CAs are per-organisation — baking one into a public image
would be wrong. Instead, dock images are designed to make extension
trivial: run `dock-bootstrap` and your trust store is ready.

### Registry mirrors

Registry configuration is org-specific. Use the standard environment
variables that each tool already respects:

| Tool  | Env var               | Example                                 |
| ----- | --------------------- | --------------------------------------- |
| npm   | `NPM_CONFIG_REGISTRY` | `https://artifactory.corp/npm/`         |
| pip   | `PIP_INDEX_URL`       | `https://artifactory.corp/pypi/simple/` |
| Cargo | (needs config file)   | See below                               |

For Cargo, write `$CARGO_HOME/config.toml` in a setup script:

```toml
[source.crates-io]
replace-with = "corp-mirror"

[source.corp-mirror]
registry = "https://artifactory.corp/cargo/"
```

Set these as CI/CD variables at the group or instance level in your
CI platform — no changes to dock images needed.

### Verifying connectivity in CI

Add a connectivity check job to confirm your extended image can
reach public and private registries:

**GitLab CI** (`.gitlab-ci.yml`):

```yaml
verify-connectivity:
  image: your-corp-image:latest
  before_script:
    - dock-bootstrap
  script:
    - "curl -sSf https://registry.npmjs.org/ > /dev/null
        && echo 'npmjs: ok'"
    - "curl -sSf https://crates.io/api/v1/crates?per_page=1
        > /dev/null && echo 'crates.io: ok'"
    - "curl -sSf https://pypi.org/simple/ > /dev/null
        && echo 'pypi: ok'"
    # Internal registries:
    - "curl -sSf https://artifactory.corp/ > /dev/null
        && echo 'artifactory: ok'"
```

If any `curl` call fails, the job fails — catching TLS or proxy
misconfigurations before they break real builds.
