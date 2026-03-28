/// Adds two 32-bit integers and returns the result.
/// Exported as a C-compatible symbol for Deno FFI.
#[unsafe(no_mangle)]
pub extern "C" fn ffi_add(a: i32, b: i32) -> i32 {
    a + b
}
