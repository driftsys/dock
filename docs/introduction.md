# dock

Lean, layered CI Docker images published at
[ghcr.io/driftsys/dock](https://github.com/driftsys/dock/pkgs/container/dock)
and [Docker Hub](https://hub.docker.com/r/driftsys/dock).

Each image adds exactly one concern — scripting foundation, compilation
toolchain, or language runtime — so teams pick the smallest image that
covers their pipeline.

## Why dock?

- **Small** — Alpine-based images start at ~32 MB (vs ~600 MB for
  typical CI images).
- **Layered** — every image inherits from `:core`, so all pipelines
  share the same scripting tools (git, curl, jq, yq, gpg, …).
- **Multi-arch** — every image ships for `linux/amd64` and
  `linux/arm64`.
- **Variant tags** — `:image-alpine` (musl) and `:image-debian` (glibc),
  plus a bare `:image` pointing at the recommended one. Some images are
  Debian-only where the upstream toolchain requires glibc.
- **Inspectable** — each image records installed tool versions in
  `/etc/dock/manifest.json`.

## Image catalog

Sizes are compressed (download) size, amd64. The **`:image` →** column is the
variant the bare `:image` tag resolves to.

| Image          | From       | `:image` → | Alpine  | Debian  | Contents                            |
| -------------- | ---------- | ---------- | ------- | ------- | ----------------------------------- |
| `:core`        | alpine     | alpine     | ~30 MB  | ~76 MB  | Shell, Git, curl, jq, yq, gpg       |
| `:rust`        | `:core`    | debian     | ~557 MB | ~551 MB | Rust stable, cargo, clippy, rustfmt |
| `:deno`        | `:core`    | alpine     | ~78 MB  | ~121 MB | Deno runtime, npx/npm shims         |
| `:node`        | `:core`    | alpine     | ~54 MB  | ~135 MB | Node.js LTS, npm                    |
| `:lint`        | `:deno`    | alpine     | ~92 MB  | ~135 MB | dprint, shellcheck, editorconfig    |
| `:std`         | `:core`    | alpine     | ~32 MB  | ~77 MB  | git-std (commits, changelog, hooks) |
| `:pages`       | `:core`    | alpine     | ~77 MB  | ~134 MB | mdbook, typst, tera-cli, lychee     |
| `:python`      | `:core`    | debian     | —       | ~104 MB | Python 3, pip, ruff                 |
| `:prose`       | `:core`    | debian     | —       | ~106 MB | vale, typos, harper-cli             |
| `:polyglot`    | `:rust`    | debian     | —       | ~625 MB | Rust + Deno + Python 3              |
| `:jvm`         | `:core`    | debian     | —       | ~218 MB | JDK 17 headless                     |
| `:android`     | `:jvm`     | debian     | —       | ~489 MB | Android SDK, build-tools            |
| `:android-ndk` | `:android` | debian     | —       | ~1.7 GB | NDK + Rust + cargo-ndk              |

## Inheritance tree

### Alpine

```
alpine:3.21
  └── :core          (~30 MB)
      ├── :rust      (~557 MB)
      ├── :deno      (~78 MB)
      │   └── :lint  (~92 MB, amd64 only)
      ├── :node      (~54 MB)
      ├── :std       (~32 MB, amd64 only)
      └── :pages     (~77 MB, amd64 only)
```

### Debian

```
debian:bookworm-slim
  └── :core-debian              (~76 MB)
      ├── :rust-debian          (~551 MB)
      │   └── :polyglot-debian  (~625 MB)
      ├── :deno-debian          (~121 MB)
      │   └── :lint-debian      (~135 MB, amd64 only)
      ├── :node-debian          (~135 MB)
      ├── :std-debian           (~77 MB, amd64 only)
      ├── :python-debian        (~104 MB)
      ├── :pages-debian         (~134 MB, amd64 only)
      ├── :prose-debian         (~106 MB)
      └── :jvm-debian           (~218 MB)
          └── :android-debian   (~489 MB)
              └── :android-ndk-debian (~1.7 GB)
```
