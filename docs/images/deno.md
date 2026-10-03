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

| Tool | Install method      | Purpose                                      |
| ---- | ------------------- | -------------------------------------------- |
| deno | official LTS binary | TypeScript/JavaScript runtime                |
| npx  | shell shim          | Run npm packages via `deno run -A npm:<pkg>` |
| npm  | shell shim          | Delegates supported npm commands to Deno     |

Deno 2.9.3 is downloaded from the official LTS distribution at `dl.deno.land`.
The Alpine build takes bundled glibc libraries from the official `denoland/deno`
image and patches the LTS binary to use those libraries. The version is
controlled by the `DENO_VERSION` build argument.

The current upstream LTS download still reports `stable` in its version banner,
including after `deno upgrade lts`. The selected version follows the upstream
LTS endpoint; the tests verify the supported 2.9 release line.

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

| Argument       | Default | Description                 |
| -------------- | ------- | --------------------------- |
| `DENO_VERSION` | `2.9.3` | Deno LTS release to install |

## Approximate size

Compressed download size for `linux/amd64`.

| Variant | Size    |
| ------- | ------- |
| Alpine  | ~88 MB  |
| Debian  | ~137 MB |
