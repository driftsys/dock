import { assertEquals } from "jsr:@std/assert";
import { add } from "./main.ts";

Deno.test("add returns the correct sum", () => {
  assertEquals(add(1, 2), 3);
});
