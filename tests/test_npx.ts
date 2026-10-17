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
for (const spec of ["tool@latest", "tool@^2.3.0", "tool"]) {
  Deno.test(`preserves explicit selection ${spec}`, async () => {
    const result = await invoke(["-p", spec, "tool"]);
    equal(result.code, 0);
    equal(JSON.parse(result.out).args, ["run", "--allow-all", `npm:${spec}`]);
  });
}

Deno.test("propagates child failure status and stderr", async () => {
  const result = await invoke(["tool"], 37);
  equal(result.code, 37);
  equal(JSON.parse(result.out), {
    args: ["run", "--allow-all", "npm:tool"],
    cwd: result.dir,
    input: "input with spaces\n",
  });
  equal(result.err, "controlled child stderr\n");
});
for (
  const args of [
    [],
    ["--", "--package=tool", "tool"],
    ["./tool"],
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

for (const signal of ["SIGTERM", "SIGINT", "SIGHUP"] as Deno.Signal[]) {
  Deno.test(`forwards ${signal} and waits for child termination`, async () => {
    const dir = await Deno.makeTempDir();
    let toolPid: number | undefined;
    let child: Deno.ChildProcess | undefined;
    try {
      const quote = (value: string) =>
        "'" + value.replaceAll("'", "'\\''") + "'";
      await Deno.writeTextFile(
        `${dir}/deno`,
        `#!/bin/sh\nexec ${quote(Deno.execPath())} run --allow-all ${
          quote(fixture)
        } "$@"\n`,
      );
      await Deno.chmod(`${dir}/deno`, 0o755);
      child = new Deno.Command(Deno.execPath(), {
        args: ["run", "--allow-run", shim, "tool"],
        env: { PATH: dir, NPX_TEST_WAIT: "1" },
        stdin: "null",
        stdout: "piped",
        stderr: "null",
      }).spawn();
      const reader = child.stdout.getReader();
      const ready = await reader.read();
      reader.releaseLock();
      toolPid = Number(decoder.decode(ready.value).trim());
      if (!toolPid) throw new Error("Child did not report its PID");
      child.kill(signal);
      const timeout = setTimeout(() => {
        try {
          child?.kill("SIGKILL");
        } catch { /* Already exited. */ }
      }, 3000);
      let status: Deno.CommandStatus;
      try {
        status = await child.status;
      } finally {
        clearTimeout(timeout);
      }
      equal(
        status.code,
        {
          SIGTERM: 143,
          SIGINT: 130,
          SIGHUP: 129,
        }[signal as "SIGTERM" | "SIGINT" | "SIGHUP"],
      );
      let alive = true;
      try {
        Deno.kill(toolPid, 0);
      } catch (error) {
        if (!(error instanceof Deno.errors.NotFound)) throw error;
        alive = false;
      }
      equal(alive, false);
    } finally {
      if (toolPid) {
        try {
          Deno.kill(toolPid, "SIGKILL");
        } catch { /* Already exited. */ }
      }
      if (child) {
        try {
          child.kill("SIGKILL");
        } catch { /* Already exited. */ }
        await child.status;
        await child.stdout.cancel();
      }
      await Deno.remove(dir, { recursive: true });
    }
  });
}
