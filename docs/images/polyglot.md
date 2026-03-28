# :polyglot

All-in-one image for mixed-language pipelines. Inherits all `:rust` tools
(which include all `:core` tools), and adds Deno and Python 3.

## Base

`FROM ghcr.io/driftsys/dock:rust` (via build context)

## Installed tools

Includes everything from `:rust` plus:

| Tool    | Install method         | Purpose                       |
| ------- | ---------------------- | ----------------------------- |
| deno    | official static binary | TypeScript/JavaScript runtime |
| python3 | apk                    | Python 3 interpreter          |
| pip     | apk (py3-pip)          | Package installer             |
| ruff    | pip                    | Linter and formatter          |

## Use case: Deno FFI with Rust

The polyglot image supports Deno's Foreign Function Interface (FFI) to
call Rust-compiled shared libraries:

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

## Approximate size

~382 MB (Alpine)
