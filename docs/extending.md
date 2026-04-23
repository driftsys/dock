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

Corporate networks often use TLS-intercepting proxies or internal CAs
that standard images don't trust. `dock-bootstrap` solves this with
a layered approach that works on both standard Docker hosts and
restricted Kubernetes runners.

#### Quick start

```yaml
# GitLab CI
default:
  before_script:
    - dock-bootstrap
    - . /etc/dock/ca.env 2>/dev/null || true
```

```yaml
# GitHub Actions
jobs:
  build:
    runs-on: ubuntu-latest
    container: ghcr.io/driftsys/dock:rust
    steps:
      - run: |
          dock-bootstrap
          . /etc/dock/ca.env 2>/dev/null || true
      - uses: actions/checkout@v4
      - run: cargo build --release
```

#### How it works

`dock-bootstrap` operates in four layers:

**Layer 1 — Dockerfile ENV defaults.** Every dock image sets TLS
environment variables at build time so all tools look at the system
CA bundle by default:

| Variable              | Tool(s)            |
| --------------------- | ------------------ |
| `SSL_CERT_FILE`       | OpenSSL, curl, git |
| `CURL_CA_BUNDLE`      | curl               |
| `GIT_SSL_CAINFO`      | git                |
| `CARGO_HTTP_CAINFO`   | cargo              |
| `NODE_EXTRA_CA_CERTS` | Node.js            |
| `DENO_CERT`           | Deno               |
| `PIP_CERT`            | pip                |

All point at `/etc/ssl/certs/ca-certificates.crt` — the system
bundle managed by `update-ca-certificates`. No runtime action is
needed when this file is writable.

**Layer 2 — Certificate source detection.** `dock-bootstrap` scans
three sources and copies discovered certs into
`/usr/local/share/ca-certificates/`:

1. **Environment variables** — any env var whose value contains
   `-----BEGIN CERTIFICATE-----` is extracted. Variables may hold
   multiple PEM blocks; each is split into a separate file. Works
   with CI/CD variables set at the group or instance level in
   GitLab, GitHub Actions secrets, or any platform that injects
   env vars into containers.
2. **Drop directory** (`/etc/dock/ca.d/` or a custom path passed
   as `$1`) — `.crt` and `.pem` files are copied directly. This
   is the most portable approach: mount a volume, use an init
   container, or `COPY` certs into the image at build time.
3. **`CI_SERVER_TLS_CA_FILE`** — the GitLab runner-provided CA
   file, if present. Ignored on non-GitLab runners.

If your infrastructure doesn't inject certs via environment
variables, use the drop directory. For example, mount a volume
from a Kubernetes secret or ConfigMap:

```yaml
# Kubernetes pod spec / GitLab runner config
volumes:
  - name: corp-ca
    secret:
      secretName: corporate-ca-certs
volumeMounts:
  - name: corp-ca
    mountPath: /etc/dock/ca.d
    readOnly: true
```

Or copy certs at build time in a derived image:

```dockerfile
FROM ghcr.io/driftsys/dock:core
COPY my-corp-ca.crt /etc/dock/ca.d/
```

**Layer 3 — Trust store update.** With certs in place,
`dock-bootstrap` tries `update-ca-certificates` to rebuild the
system bundle. If that succeeds (the normal case on Docker hosts
and VMs), all tools see the new CAs immediately — done.

**Layer 4 — Read-only fallback.** On Kubernetes runners,
`/etc/ssl/certs/` is often mounted as a read-only ConfigMap.
When `update-ca-certificates` fails, `dock-bootstrap`:

1. Builds a private bundle at `/etc/dock/ca-bundle.crt` by
   copying the existing system bundle (preserving any cluster-
   injected CAs from the ConfigMap) and appending the imported
   certs.
2. Writes `/etc/dock/ca.env` with export statements that
   redirect every variable from Layer 1 to the new bundle.

**You must source `/etc/dock/ca.env`** to activate the fallback
bundle. The file only exists when the fallback triggers, so the
`. /etc/dock/ca.env 2>/dev/null || true` line is harmless on
standard Docker hosts — always include it.

#### Skipping CA detection

Jobs that don't need corporate CAs can skip detection entirely:

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

### Pulling dock images from private registries

dock images are published to both GHCR (`ghcr.io/driftsys/dock`) and
Docker Hub (`docker.io/driftsys/dock`). Use whichever your network
allows.

If your Kubernetes cluster restricts image pulls to approved
registries (e.g. via admission policies like Kyverno or
Gatekeeper), mirror the images through your internal registry:

```bash
# One-time mirror setup (e.g. via Artifactory, Nexus, or Harbor)
# Mirror ghcr.io/driftsys/dock → registry.corp/driftsys/dock
```

Then reference the mirror in your CI configuration:

**GitLab CI:**

```yaml
variables:
  DOCK_REGISTRY: "registry.corp/driftsys/dock"
  DOCK_VERSION: "0.1.6"

default:
  image: ${DOCK_REGISTRY}:core-${DOCK_VERSION}
  before_script:
    - dock-bootstrap
    - . /etc/dock/ca.env 2>/dev/null || true
```

**GitHub Actions:**

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    container: registry.corp/driftsys/dock:rust-0.1.6
    steps:
      - run: dock-bootstrap
      - uses: actions/checkout@v4
      - run: cargo build --release
```

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
    - . /etc/dock/ca.env 2>/dev/null || true
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
