# :std

`git-std` toolbox. Inherits all `:core` tools (shell, git, curl, jq, …).

## Base

| Variant          | Base                                                |
| ---------------- | --------------------------------------------------- |
| Alpine (default) | `ghcr.io/driftsys/dock:core` (build context)        |
| Debian           | `ghcr.io/driftsys/dock:core-debian` (build context) |

## Installed tools

| Tool    | Install method           | Purpose                                            |
| ------- | ------------------------ | -------------------------------------------------- |
| git-std | binary (GitHub releases) | Conventional commits, changelog, versioning, hooks |

`git-std` is a single static binary that replaces commitizen, commitlint,
standard-version, husky, and lefthook. Invoke it directly (`git-std …`) or
as a git subcommand (`git std …`).

## Platform note

`git-std` releases only provide a Linux x86_64 binary. This image is
built for `linux/amd64` only.

## Usage in CI

```yaml
jobs:
  commits:
    runs-on: ubuntu-latest
    container: ghcr.io/driftsys/dock:std
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - run: git std lint --range origin/main..HEAD
```

## Build arguments

| Argument          | Default   | Description                |
| ----------------- | --------- | -------------------------- |
| `GIT_STD_VERSION` | `0.11.12` | git-std release to install |

## Approximate size

| Variant | Size   |
| ------- | ------ |
| Alpine  | ~32 MB |
| Debian  | ~77 MB |
