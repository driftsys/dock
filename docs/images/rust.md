# :rust

Rust compilation toolchain. Inherits all `:core` tools.

The bare **`:rust` tag is the Debian (gnu) variant** — the Rust tier-1 target
with the widest crate compatibility. Use **`:rust-alpine`** when you want static
musl binaries.

## Base

| Variant          | Base                                       |
| ---------------- | ------------------------------------------ |
| Alpine           | `ghcr.io/driftsys/dock:core` (build        |
|                  | context)                                   |
| Debian (default) | `ghcr.io/driftsys/dock:core-debian` (build |
|                  | context)                                   |

## Installed tools

| Tool         | Install method           | Purpose                           |
| ------------ | ------------------------ | --------------------------------- |
| rustc, cargo | rustup stable            | Rust compiler and package manager |
| clippy       | rustup component         | Linter                            |
| rustfmt      | rustup component         | Formatter                         |
| cargo-audit  | `cargo install --locked` | Security advisory scanner         |
| clippy-sarif | `cargo install --locked` | Clippy JSON to SARIF              |
| sarif-fmt    | `cargo install --locked` | Readable SARIF diagnostics        |
| cargo-deny   | `cargo install --locked` | Dependency policy checker         |
| gcc, g++     | apk (Alpine)             | C/C++ compiler for build scripts  |
| musl-dev     | apk                      | musl libc headers                 |
| pkg-config   | pkgconf (apk)            | Build configuration helper        |
| openssl-dev  | apk                      | OpenSSL headers for Rust crates   |

## Usage in CI

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    container: ghcr.io/driftsys/dock:rust
    steps:
      - uses: actions/checkout@v4
      - run: cargo test
      - run: cargo clippy -- -D warnings
      - run: cargo audit
```

## SARIF artifacts

Both variants build native `clippy-sarif` and `sarif-fmt` binaries pinned to
`0.8.0`. The Debian polyglot image inherits both tools and their manifest
entries. Producer jobs require no GitLab token:

```bash
mkdir -p findings
cargo clippy --all-targets --message-format=json > findings/clippy.json
clippy-sarif < findings/clippy.json | tee findings/clippy.sarif | sarif-fmt
```

Upload `findings/*.sarif` with `when: always`, then use the
[GitLab reporting image](glab.md) for Code Quality and diff-filtered MR threads.
If Clippy is configured to fail on warnings, still run conversion and preserve
its exit status for the producer job.

The installed cargo-audit and cargo-deny releases also offer native SARIF:

```bash
cargo audit --format sarif > findings/audit.sarif
cargo deny --format sarif check > findings/deny.sarif
```

## Build arguments

| Argument               | Default | Description            |
| ---------------------- | ------- | ---------------------- |
| `CLIPPY_SARIF_VERSION` | `0.8.0` | Clippy SARIF converter |
| `SARIF_FMT_VERSION`    | `0.8.0` | SARIF log formatter    |

## Approximate size

| Variant | Size    |
| ------- | ------- |
| Alpine  | ~260 MB |
| Debian  | ~330 MB |
