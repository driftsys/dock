# :node

Node.js LTS runtime. Inherits all `:core` tools.

## Base

`FROM ghcr.io/driftsys/dock:core` (via build context)

## Installed tools

| Tool | Install method | Purpose             |
| ---- | -------------- | ------------------- |
| node | apk (nodejs)   | Node.js LTS runtime |
| npm  | apk (npm)      | Package manager     |

## Usage in CI

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    container: ghcr.io/driftsys/dock:node
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm test
```

## Approximate size

~115 MB (Alpine)
