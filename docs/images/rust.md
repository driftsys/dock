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

| Tool               | Install method           | Purpose                           |
| ------------------ | ------------------------ | --------------------------------- |
| rustc, cargo       | rustup stable            | Rust compiler and package manager |
| clippy             | rustup component         | Linter                            |
| rustfmt            | rustup component         | Formatter                         |
| cargo-nextest      | Pinned official binary   | Test runner with JUnit reports    |
| cargo-llvm-cov     | Pinned official binary   | LLVM coverage and report export   |
| llvm-tools-preview | rustup component         | LLVM tools matching rustc         |
| cargo-audit        | `cargo install --locked` | Security advisory scanner         |
| clippy-sarif       | `cargo install --locked` | Clippy JSON to SARIF              |
| sarif-fmt          | `cargo install --locked` | Readable SARIF diagnostics        |
| cargo-deny         | `cargo install --locked` | Dependency policy checker         |
| gcc, g++           | apk (Alpine)             | C/C++ compiler for build scripts  |
| musl-dev           | apk                      | musl libc headers                 |
| pkg-config         | pkgconf (apk)            | Build configuration helper        |
| openssl-dev        | apk                      | OpenSSL headers for Rust crates   |

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

## Tests and coverage

Both variants include cargo-nextest **0.9.146**, cargo-llvm-cov **0.9.1**, and
`llvm-tools-preview` from the active stable Rust toolchain. They use upstream
binaries for `x86_64` and `aarch64`, matching each variant's libc. Downloads are
verified against the SHA-256 hashes in `scripts/rust-coverage.sha256`. Updating
the tool version build arguments also requires updating these hashes.

The tested combination is Rust **1.99.0** with LLVM **23.1.1**. LLVM coverage
must use tools compatible with the compiler that produced the instrumentation.
If you select another toolchain, install its `llvm-tools-preview` component when
building your derived image. The bundled tools need no installation in CI jobs.
See the upstream [nextest binaries][nextest-binaries] and
[cargo-llvm-cov documentation][llvm-cov-docs] for platform and version support.

Add `.config/nextest.toml` to your project:

```toml
[profile.ci]
fail-fast = false

[profile.ci.junit]
path = "junit.xml"
```

Run instrumented tests once, then render reports from the same coverage data:

```bash
export CARGO_LLVM_COV_SETUP=no
cargo llvm-cov clean --workspace
status=0
cargo llvm-cov --no-report nextest --profile ci || status=$?
mkdir -p reports
cp target/nextest/ci/junit.xml reports/junit.xml
cargo llvm-cov report --cobertura --output-path reports/cobertura.xml
cargo llvm-cov report --lcov --output-path reports/lcov.info
cargo llvm-cov report --json --summary-only --output-path reports/summary.json
exit "$status"
```

Run this as a shell script. Reports are rendered even when a test fails; the
script preserves the test exit status. Use fresh job directories or clean old
reports first to avoid uploading stale evidence. JUnit is a test result format;
Cobertura, LCOV, and JSON describe coverage. In GitLab, upload artifacts with
`when: always`, configure JUnit and Cobertura report paths, and retain LCOV and
JSON as ordinary artifacts.

The dependency-free fixture in `tests/fixtures/rust-coverage/` verifies both
success and failure with networking disabled. Rust and Debian polyglot tests
include these checks; CI builds and executes them on native amd64 and arm64
runners, and scheduled health checks exercise the published variants.

[nextest-binaries]: https://nexte.st/docs/installation/pre-built-binaries/
[llvm-cov-docs]: https://github.com/taiki-e/cargo-llvm-cov

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

| Argument                 | Default   | Description            |
| ------------------------ | --------- | ---------------------- |
| `CLIPPY_SARIF_VERSION`   | `0.8.0`   | Clippy SARIF converter |
| `SARIF_FMT_VERSION`      | `0.8.0`   | SARIF log formatter    |
| `CARGO_NEXTEST_VERSION`  | `0.9.146` | Test runner            |
| `CARGO_LLVM_COV_VERSION` | `0.9.1`   | Coverage driver        |

## Approximate size

| Variant | Size    |
| ------- | ------- |
| Alpine  | ~634 MB |
| Debian  | ~459 MB |

These are compressed arm64 sizes. The minimal rustup profile omits offline Rust
documentation while retaining Clippy and rustfmt. Cargo registry and git caches
used to install tools are removed in the layers that create them; coverage
downloads are temporary. The complete matching LLVM component is retained. Its
musl binaries are larger than its glibc binaries, so Debian is also the smaller
coverage variant. Polyglot inherits the Debian tools and manifest entries
without duplicating the Rust layer.
