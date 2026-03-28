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
