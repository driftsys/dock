# :rust

Rust compilation toolchain. Inherits all `:core` tools.

The bare **`:rust` tag is the Debian (gnu) variant** — the Rust tier-1 target
with the widest crate compatibility. Use **`:rust-alpine`** when you want
static musl binaries.

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

## Approximate size

| Variant | Size    |
| ------- | ------- |
| Alpine  | ~260 MB |
| Debian  | ~330 MB |
