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

| Tool | Install method         | Purpose                                      |
| ---- | ---------------------- | -------------------------------------------- |
| deno | official static binary | TypeScript/JavaScript runtime                |
| npx  | shell shim             | Run npm packages via `deno run -A npm:<pkg>` |
| npm  | shell shim             | Delegates supported npm commands to Deno     |

Deno is installed from the official GitHub release binary. The version
is controlled by the `DENO_VERSION` build argument.

The `npx` and `npm` shims allow using npm ecosystem tools without
installing Node.js. They delegate to Deno under the hood:

```bash
# Run any npm package
npx markdownlint-cli2 "**/*.md"
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

| Variant | Size    |
| ------- | ------- |
| Alpine  | ~120 MB |
| Debian  | ~175 MB |
