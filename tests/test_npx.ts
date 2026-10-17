// Exercise the complete shim with a controlled deno child on PATH.
const shim = Deno.env.get("NPX_SHIM") ??
  new URL("../utils/npx.ts", import.meta.url).pathname;
const fixture = new URL("fixtures/npx/child.ts", import.meta.url).pathname;
const decoder = new TextDecoder();
function equal(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}
async function invoke(args: string[], exit = 0) {
  const dir = await Deno.realPath(
    await Deno.makeTempDir({ prefix: "npx space " }),
  );
  try {
    const quote = (value: string) => "'" + value.replaceAll("'", "'\\''") + "'";
    await Deno.writeTextFile(
      `${dir}/deno`,
      `#!/bin/sh\nexec ${quote(Deno.execPath())} run --allow-all ${
        quote(fixture)
      } "$@"\n`,
    );
    await Deno.chmod(`${dir}/deno`, 0o755);
    const child = new Deno.Command(Deno.execPath(), {
      args: ["run", "--allow-all", shim, ...args],
      cwd: dir,
      env: { PATH: dir, NPX_TEST_EXIT: String(exit) },
      stdin: "piped",
      stdout: "piped",
      stderr: "piped",
    }).spawn();
    const writer = child.stdin.getWriter();
    await writer.write(new TextEncoder().encode("input with spaces\n"));
    await writer.close();
    const result = await child.output();
    return {
      code: result.code,
      out: decoder.decode(result.stdout),
      err: decoder.decode(result.stderr),
      dir,
    };
  } finally {
    await Deno.remove(dir, { recursive: true });
  }
}
for (
  const [name, args, spec, forwarded] of [
    ["direct", ["tool@1.2.3", "a b", "", "--yes"], "tool@1.2.3", [
      "a b",
      "",
      "--yes",
    ]],
    [
      "required example",
      [
        "--yes",
        "--package=gitlab-ci-local@4.75.0",
        "gitlab-ci-local",
        "--preview",
      ],
      "gitlab-ci-local@4.75.0",
      ["--preview"],
    ],
    [
      "separate package",
      ["-y", "--package", "tool@2", "tool", "a b"],
      "tool@2",
      ["a b"],
    ],
    ["short package", ["-p", "tool@2", "tool"], "tool@2", []],
    [
      "scoped",
      ["-p", "@scope/tool@2.3.4", "tool", "--flag"],
      "@scope/tool@2.3.4",
      ["--flag"],
    ],
    ["direct scoped", ["@scope/tool@2.3.4"], "@scope/tool@2.3.4", []],
    ["delimiter", ["--package=tool@2", "--", "tool", "--", "a b"], "tool@2", [
      "--",
      "a b",
    ]],
  ] as [string, string[], string, string[]][]
) {
  Deno.test(name, async () => {
    const result = await invoke(args);
    equal(result.code, 0);
    equal(JSON.parse(result.out), {
      args: ["run", "--allow-all", `npm:${spec}`, ...forwarded],
      cwd: result.dir,
      input: "input with spaces\n",
    });
    equal(result.err, "controlled child stderr\n");
  });
}
Deno.test("propagates child failure status and stderr", async () => {
  const result = await invoke(["tool"], 37);
  equal(result.code, 37);
  equal(result.err, "controlled child stderr\n");
});
for (
  const args of [
    [],
    ["--unknown"],
    ["--no"],
    ["-c", "tool"],
    ["--package"],
    ["-p"],
    ["--package="],
    ["--package", "--yes"],
    ["-p", "tool"],
    ["-p", "tool", "-p", "other", "tool"],
    ["--package=tool", "--package=tool", "tool"],
    ["-p", "tool@1", "other"],
    ["-p", "@scope/tool@1", "@scope/tool"],
    ["@scope"],
    ["tool@"],
    ["https://example.com/tool"],
  ]
) {
  Deno.test(`rejects ${JSON.stringify(args)}`, async () => {
    const result = await invoke(args);
    equal(result.code, 1);
    equal(result.out, "");
    if (!result.err.startsWith("npx:")) throw new Error(result.err);
  });
}
