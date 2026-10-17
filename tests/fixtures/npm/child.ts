if (Deno.env.get("NPM_TEST_SIGNAL")) {
  const signal = Deno.env.get("NPM_TEST_SIGNAL") as Deno.Signal;
  Deno.addSignalListener(signal, () => {
    console.error(`received ${signal}`);
    setTimeout(() => {
      console.log("cleanup complete");
      Deno.exit(43);
    }, 100);
  });
  console.log(Deno.pid);
  setInterval(() => {}, 1000);
  await new Promise(() => {});
}
const input = await new Response(Deno.stdin.readable).text();
console.log(JSON.stringify({ args: Deno.args, cwd: Deno.cwd(), input }));
console.error("controlled npm child stderr");
Deno.exit(Number(Deno.env.get("NPM_TEST_EXIT") ?? "0"));
