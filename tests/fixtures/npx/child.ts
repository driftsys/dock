if (Deno.env.get("NPX_TEST_WAIT") === "1") {
  console.log(Deno.pid);
  setInterval(() => {}, 1000);
  await new Promise(() => {});
}
const input = await new Response(Deno.stdin.readable).text();
console.log(JSON.stringify({ args: Deno.args, cwd: Deno.cwd(), input }));
console.error("controlled child stderr");
Deno.exit(Number(Deno.env.get("NPX_TEST_EXIT") ?? "0"));
