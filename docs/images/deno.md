# :deno

Deno runtime. Inherits all `:core` tools.

## Base

| Variant          | Base                                       |
| ---------------- | ------------------------------------------ |
| Alpine (default) | `ghcr.io/driftsys/dock:core` (build        |
|                  | context)                                   |
| Debian           | `ghcr.io/driftsys/dock:core-debian` (build |
|                  | context)                                   |

## Installed tools

| Tool | Install method        | Purpose                                      |
| ---- | --------------------- | -------------------------------------------- |
| deno | official Docker image | TypeScript/JavaScript runtime                |
| npx  | shell shim            | Run npm packages via `deno run -A npm:<pkg>` |
| npm  | shell shim            | Delegates supported npm commands to Deno     |

Deno is copied from the official `denoland/deno` Docker image via a multi-stage
build (along with its bundled runtime libraries). The version is controlled by
the `DENO_VERSION` build argument.

The Alpine binary resolves its bundled glibc libraries through its patched
RPATH. The image does not set a global `LD_LIBRARY_PATH`, so core tools such as
ripgrep continue to use Alpine's musl libraries.

The `npx` and `npm` shims allow using npm ecosystem tools without installing
Node.js. They delegate to Deno under the hood:

```bash
# Run any npm package
npx prettier --check .

# npm shim supports: install, ci, run, test, init
npm install   # → deno install
npm run build # → deno task build
```

## Usage in CI

```yaml
jobs:
  check:
    runs-on: ubuntu-latest
    container: ghcr.io/driftsys/dock:deno
    steps:
      - uses: actions/checkout@v4
      - run: deno lint
      - run: deno fmt --check
      - run: deno test
```

## Build arguments

| Argument       | Default | Description             |
| -------------- | ------- | ----------------------- |
| `DENO_VERSION` | `2.8.1` | Deno release to install |

## Approximate size

Compressed download size for `linux/amd64`.

| Variant | Size    |
| ------- | ------- |
| Alpine  | ~88 MB  |
| Debian  | ~137 MB |
