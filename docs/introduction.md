# dock

Lean, layered CI Docker images published at
[ghcr.io/driftsys/dock](https://github.com/driftsys/dock/pkgs/container/dock)
and [Docker Hub](https://hub.docker.com/r/driftsys/dock).

Each image adds exactly one concern — scripting foundation, compilation
toolchain, or language runtime — so teams pick the smallest image that
covers their pipeline.

## Why dock?

- **Small** — Alpine-based images start at ~32 MB (vs ~600 MB for typical
  CI images).
- **Layered** — every image inherits from `:core`, so all pipelines share
  the same scripting tools (git, curl, jq, yq, gpg, ...).
- **Multi-arch** — every image ships for `linux/amd64` and `linux/arm64`.
- **Dual-variant** — Alpine (musl, default) and Debian (glibc) for each
  image.
- **Inspectable** — each image records installed tool versions in
  `/etc/dock/manifest.json`.

## Image catalog

| Image       | From    | Size (Alpine) | Contents                                   |
| ----------- | ------- | ------------- | ------------------------------------------ |
| `:core`     | alpine  | ~32 MB        | Shell, Git, curl, jq, yq, gpg             |
| `:rust`     | `:core` | ~260 MB       | Rust stable, cargo, clippy, rustfmt        |
| `:deno`     | `:core` | ~120 MB       | Deno runtime                               |
| `:node`     | `:core` | ~115 MB       | Node.js LTS, npm                           |
| `:python`   | `:core` | ~55 MB        | Python 3, pip, ruff                        |
| `:polyglot` | `:rust` | ~382 MB       | Rust + Deno + Python 3                     |
| `:lint`     | `:core` | ~44 MB        | shellcheck, editorconfig-checker, git-std  |

## Inheritance tree

```
alpine:3.21
  └── :core              (~32 MB)
      ├── :rust          (~260 MB)
      │   └── :polyglot  (~382 MB)
      ├── :deno          (~120 MB)
      ├── :node          (~115 MB)
      ├── :python        (~55 MB)
      └── :lint          (~44 MB, amd64 only)
```
