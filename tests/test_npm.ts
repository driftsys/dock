// Run the adapter against an executable recorder instead of the real Deno child.
const shim = Deno.env.get("NPM_SHIM") ??
  new URL("../utils/npm.ts", import.meta.url).pathname;
const fixture = new URL("fixtures/npm/child.ts", import.meta.url).pathname;
const decoder = new TextDecoder();
const encoder = new TextEncoder();
function equal(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}
const quote = (value: string) => "'" + value.replaceAll("'", "'\\''") + "'";
async function setupChild() {
  const dir = await Deno.realPath(
    await Deno.makeTempDir({ prefix: "npm space " }),
  );
  await Deno.mkdir(`${dir}/project space`);
  await Deno.writeTextFile(
    `${dir}/deno`,
    `#!/bin/sh\nexec ${quote(Deno.execPath())} run --allow-all ${
      quote(fixture)
    } "$@"\n`,
  );
  await Deno.chmod(`${dir}/deno`, 0o755);
  return dir;
}
async function invoke(args: string[], exit = 0, missingChild = false) {
  const dir = await setupChild();
  try {
    if (missingChild) await Deno.remove(`${dir}/deno`);
    const child = new Deno.Command(Deno.execPath(), {
      args: ["run", "--allow-run", shim, ...args],
      cwd: dir,
      env: { PATH: dir, NPM_TEST_EXIT: String(exit) },
      stdin: "piped",
      stdout: "piped",
      stderr: "piped",
    }).spawn();
    const writer = child.stdin.getWriter();
    await writer.write(encoder.encode("npm stdin with spaces\n"));
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
const cases: [string[], string[], boolean?][] = [
  [["install"], ["install"]],
  [["install", "--", "one"], ["install", "--package-json", "npm:one"]],
  [["i"], ["install"]],
  [["add", "one@1", "@scope/two@^2"], [
    "install",
    "--package-json",
    "npm:one@1",
    "npm:@scope/two@^2",
  ]],
  [["install", "-D", "one@latest"], [
    "install",
    "--package-json",
    "--dev",
    "npm:one@latest",
  ]],
  [["install", "one@1", "--save-dev"], [
    "install",
    "--package-json",
    "--dev",
    "npm:one@1",
  ]],
  [["install", "--omit=dev"], ["install", "--prod"]],
  [["install", "--omit", "dev"], ["install", "--prod"]],
  [["install", "-g", "tool@1.2.3"], [
    "install",
    "--global",
    "--allow-all",
    "--root",
    "/usr/local",
    "--name",
    "tool",
    "npm:tool@1.2.3",
  ]],
  [["install", "@scope/tool@latest", "--global", "--prefix=project space"], [
    "install",
    "--global",
    "--allow-all",
    "--root",
    "project space",
    "--name",
    "tool",
    "npm:@scope/tool@latest",
  ]],
  [["--prefix", "project space", "install", "one@1"], [
    "install",
    "--package-json",
    "npm:one@1",
  ], true],
  [["install", "--prefix", "project space"], ["install"], true],
  [["uninstall", "one", "@scope/two"], [
    "uninstall",
    "--package-json",
    "one",
    "@scope/two",
  ]],
  [["remove", "-g", "@scope/tool"], [
    "uninstall",
    "--global",
    "--root",
    "/usr/local",
    "tool",
  ]],
  [["rm", "--prefix", "project space", "one"], [
    "uninstall",
    "--package-json",
    "one",
  ], true],
  [["rm", "--global", "--prefix", "project space", "tool"], [
    "uninstall",
    "--global",
    "--root",
    "project space",
    "tool",
  ]],
  [["ci"], ["install", "--frozen"]],
  [["clean-install", "--omit=dev"], ["install", "--frozen", "--prod"]],
  [["run"], ["task"]],
  [["run", "--", "build", "--watch"], ["task", "build", "--watch"]],
  [["run-script", "build"], ["task", "build"]],
  [["run", "build", "--", "--watch", "a b", ""], [
    "task",
    "build",
    "--watch",
    "a b",
    "",
  ]],
  [["run", "build", "--if-present"], ["task", "--if-present", "build"]],
  [["run", "--if-present", "build"], ["task", "--if-present", "build"]],
  [["run", "--prefix=project space", "build", "--", "--prefix", "child dir"], [
    "task",
    "build",
    "--prefix",
    "child dir",
  ], true],
  [["test", "--", "--filter", "a b"], ["task", "test", "--filter", "a b"]],
  [["t", "--if-present"], ["task", "--if-present", "test"]],
  [["init", "project space"], ["init", "project space"]],
  [["init", "-y"], ["init"]],
  [["exec", "tool@^1", "--flag", "a b"], [
    "run",
    "--allow-all",
    "npm:tool@^1",
    "--flag",
    "a b",
  ]],
  [["exec", "--yes", "--package=tool@1", "tool", "--preview"], [
    "run",
    "--allow-all",
    "npm:tool@1",
    "--preview",
  ]],
  [["exec", "-y", "--package", "@scope/tool@1", "tool"], [
    "run",
    "--allow-all",
    "npm:@scope/tool@1",
  ]],
  [["exec", "-p", "tool@1", "--", "tool", "--", "a b"], [
    "run",
    "--allow-all",
    "npm:tool@1",
    "--",
    "a b",
  ]],
];
for (const [args, expected, prefixed] of cases) {
  Deno.test(`translates ${JSON.stringify(args)}`, async () => {
    const result = await invoke(args);
    equal(result.code, 0);
    equal(JSON.parse(result.out), {
      args: expected,
      cwd: result.dir + (prefixed ? "/project space" : ""),
      input: "npm stdin with spaces\n",
    });
    equal(result.err, "controlled npm child stderr\n");
  });
}
Deno.test("preserves failure stdout, stderr, and exit code", async () => {
  const result = await invoke(["run", "build"], 37);
  equal(result.code, 37);
  equal(JSON.parse(result.out), {
    args: ["task", "build"],
    cwd: result.dir,
    input: "npm stdin with spaces\n",
  });
  equal(result.err, "controlled npm child stderr\n");
});
for (
  const args of [
    [],
    ["help", "--unknown"],
    ["help", "publish"],
    ["publish", "--help"],
    ["help", "install", "extra"],
    ["install", "--", "--global", "tool"],
    ["install", "-g", "deno"],
    ["install", "-g", "npx"],
    ["uninstall", "-g", "npm"],
    ["uninstall", "-g", "deno"],
    ["uninstall", "-g", "npx"],
    ["run", "--", "--watch"],
    ["publish"],
    ["--version"],
    ["--prefix"],
    ["--prefix="],
    ["--prefix", "--yes", "install"],
    ["install", "--prefix"],
    ["install", "--prefix=a", "--prefix=b"],
    ["install", "--registry=x"],
    ["install", "-g"],
    ["install", "-g", "one", "two"],
    ["install", "-g", "-D", "one"],
    ["install", "-g", "--omit=dev", "one"],
    ["install", "-D"],
    ["install", "-D", "--omit=dev", "one"],
    ["install", "--omit=optional"],
    ["install", "./local"],
    ["install", "https://example.com/pkg"],
    ["install", "one@"],
    ["install", "--", "--global"],
    ["install", "-g", "npm"],
    ["uninstall"],
    ["rm", "one@1"],
    ["rm", "--save-dev", "one"],
    ["rm", "-g", "one", "two"],
    ["ci", "one"],
    ["ci", "--global"],
    ["run", "--if-present"],
    ["run", "build", "--unknown"],
    ["test", "--unknown"],
    ["init", "one", "two"],
    ["init", "--unknown"],
    ["exec"],
    ["exec", "--package"],
    ["exec", "--package="],
    ["exec", "--package=one", "two"],
    ["exec", "-p", "one", "-p", "two", "one"],
    ["exec", "--no", "one"],
    ["exec", "--", "--package=one", "one"],
    ["exec", "-p", "@scope/one", "@scope/one"],
  ]
) {
  Deno.test(`rejects ${JSON.stringify(args)}`, async () => {
    const result = await invoke(args);
    equal(result.code, 1);
    equal(result.out, "");
    if (!result.err.startsWith("npm:")) throw new Error(result.err);
  });
}
for (
  const args of [["--help"], ["help"], ["install", "--help"], [
    "help",
    "install",
  ]]
) {
  Deno.test(`help ${JSON.stringify(args)}`, async () => {
    const result = await invoke(args);
    equal(result.code, 0);
    equal(result.err, "");
    if (!result.out.includes("not full npm")) throw new Error(result.out);
  });
}
Deno.test("reports child launch failure", async () => {
  const result = await invoke(["install"], 0, true);
  equal(result.code, 1);
  equal(result.out, "");
  if (!result.err.startsWith("npm:")) throw new Error(result.err);
});
for (const signal of ["SIGINT", "SIGTERM", "SIGHUP"] as Deno.Signal[]) {
  Deno.test(`waits for custom cleanup and status after ${signal}`, async () => {
    const dir = await setupChild();
    let child: Deno.ChildProcess | undefined;
    let toolPid: number | undefined;
    let timeout: ReturnType<typeof setTimeout> | undefined;
    try {
      child = new Deno.Command(Deno.execPath(), {
        args: ["run", "--allow-run", shim, "run", "build"],
        cwd: dir,
        env: { PATH: dir, NPM_TEST_SIGNAL: signal },
        stdin: "null",
        stdout: "piped",
        stderr: "piped",
      }).spawn();
      timeout = setTimeout(() => {
        try {
          child?.kill("SIGKILL");
        } catch { /* Already exited. */ }
      }, 5000);
      const reader = child.stdout.getReader();
      const ready = await reader.read();
      reader.releaseLock();
      toolPid = Number(decoder.decode(ready.value).trim());
      if (!toolPid) throw new Error("Missing child PID");
      child.kill(signal);
      const result = await child.output();
      equal(result.code, 43);
      equal(decoder.decode(result.stdout), "cleanup complete\n");
      equal(decoder.decode(result.stderr), `received ${signal}\n`);
      let alive = true;
      try {
        Deno.kill(toolPid, 0);
      } catch (error) {
        if (!(error instanceof Deno.errors.NotFound)) throw error;
        alive = false;
      }
      equal(alive, false);
    } finally {
      clearTimeout(timeout);
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
      }
      await Deno.remove(dir, { recursive: true });
    }
  });
}

Deno.test("shim is executable and has a Deno shebang", async () => {
  const mode = (await Deno.stat(shim)).mode;
  if (mode === null || (mode & 0o111) === 0) {
    throw new Error("npm shim is not executable");
  }
  equal(
    (await Deno.readTextFile(shim)).split("\n")[0],
    "#!/usr/bin/env -S deno run --allow-run",
  );
});
