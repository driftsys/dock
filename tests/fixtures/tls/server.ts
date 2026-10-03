// Local test endpoint. The committed private key is only a test fixture.
Deno.serve({
  hostname: "127.0.0.1",
  port: 0,
  cert: await Deno.readTextFile("/fixtures/tls/server.crt"),
  key: await Deno.readTextFile("/fixtures/tls/server.key"),
  onListen: ({ port }) => console.log(port),
}, (request) => {
  console.log(`request ${new URL(request.url).pathname}`);
  return Response.json({ version: "1.0.0", message: "fixture endpoint" });
});
