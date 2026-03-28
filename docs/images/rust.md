# :rust

Rust compilation toolchain. Inherits all `:core` tools.

## Base

`FROM ghcr.io/driftsys/dock:core` (via build context)

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

~260 MB (Alpine)
