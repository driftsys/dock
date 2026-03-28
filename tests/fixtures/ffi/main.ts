// Deno FFI smoke test: loads the Rust-compiled libffi_add.so and calls ffi_add.
// Usage: deno run --allow-ffi --unstable-ffi main.ts <path-to-libffi_add.so>

const libPath = Deno.args[0];
if (!libPath) {
  console.error("usage: main.ts <path-to-libffi_add.so>");
  Deno.exit(1);
}

const lib = Deno.dlopen(libPath, {
  ffi_add: { parameters: ["i32", "i32"], result: "i32" },
});

const result = lib.symbols.ffi_add(3, 4);
if (result !== 7) {
  console.error(`expected 7, got ${result}`);
  Deno.exit(1);
}

lib.close();
console.log("FFI smoke test passed:", result);
