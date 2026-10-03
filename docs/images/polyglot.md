# :polyglot

All-in-one image for mixed-language pipelines. Inherits all `:rust-debian` tools
(which include all `:core-debian` tools), and adds Deno, Python 3, uv, uvx, and
Ruff.

**Debian-only.** It bundles Python (glibc `manylinux` wheels) and Deno, so
`:polyglot` has no Alpine variant — the bare `:polyglot` tag and
`:polyglot-debian` are the same image.

## Base

| Variant | Base                                                |
| ------- | --------------------------------------------------- |
| Debian  | `ghcr.io/driftsys/dock:rust-debian` (build context) |

## Installed tools

Includes everything from `:rust` plus:

| Tool    | Install method        | Purpose                       |
| ------- | --------------------- | ----------------------------- |
| deno    | official LTS binary   | TypeScript/JavaScript runtime |
| python3 | apt                   | Python 3 interpreter          |
| pip     | apt (python3-pip)     | Package installer             |
| uv, uvx | Official Astral image | Python dependency management  |
| ruff    | Official Astral image | Linter and formatter          |

## Use case: Deno FFI with Rust

The polyglot image supports Deno's Foreign Function Interface (FFI) to call
Rust-compiled shared libraries:

```typescript
// Compile: cargo build --release --lib
const lib = Deno.dlopen("libmylib.so", {
  my_fn: { parameters: ["i32"], result: "i32" },
});
console.log(lib.symbols.my_fn(42));
lib.close();
```

## Usage in CI

```yaml
jobs:
  interop:
    runs-on: ubuntu-latest
    container: ghcr.io/driftsys/dock:polyglot
    steps:
      - uses: actions/checkout@v4
      - run: cargo build --release --lib
      - run: deno run --allow-ffi --unstable-ffi main.ts
```

## Python dependencies and reports

The image uses the same pinned uv and Ruff binaries, interpreter defaults, and
certificate configuration as [the Python image](python.md). It also inherits
`clippy-sarif` and `sarif-fmt` from Rust. See the Python page for lockfiles,
inline script dependencies, CI caching, and Ruff SARIF reporting.

## Approximate size

| Variant | Size    |
| ------- | ------- |
| Debian  | ~710 MB |
