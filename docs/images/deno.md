# :deno

Deno runtime. Inherits all `:core` tools.

## Base

`FROM ghcr.io/driftsys/dock:core` (via build context)

## Installed tools

| Tool | Install method         | Purpose                       |
| ---- | ---------------------- | ----------------------------- |
| deno | official static binary | TypeScript/JavaScript runtime |

Deno is installed from the official GitHub release binary. The version
is controlled by the `DENO_VERSION` build argument.

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
| `DENO_VERSION` | `2.3.1` | Deno release to install |

## Approximate size

~120 MB (Alpine)
