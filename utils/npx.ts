#!/usr/bin/env -S deno run --allow-run
// A limited npx adapter for one npm registry package, executed with Deno.

function translate(args: string[]): string[] {
  let selected: string | undefined;
  let index = 0;
  while (index < args.length) {
    const arg = args[index];
    if (arg === "--") {
      index++;
      break;
    }
    if (arg === "--yes" || arg === "-y") {
      index++;
      continue;
    }
    if (arg === "--package" || arg === "-p" || arg.startsWith("--package=")) {
      if (selected !== undefined) {
        throw new Error("multiple package selections are unsupported");
      }
      selected = arg.startsWith("--package=") ? arg.slice(10) : args[++index];
      if (!selected || selected.startsWith("-")) {
        throw new Error("missing package value");
      }
      index++;
      continue;
    }
    if (arg.startsWith("-")) throw new Error(`unsupported option: ${arg}`);
    break;
  }
  const command = args[index++];
  if (!command) throw new Error("missing package or command");
  const spec = selected ?? command;
  // Registry package names, optionally scoped, with an optional version, tag, or range without whitespace.
  const match =
    /^(?:@[a-z0-9_][a-z0-9._-]*\/)?([a-z0-9_][a-z0-9._-]*)(?:@([^\s/@]+))?$/
      .exec(spec);
  if (!match) throw new Error(`unsupported package specifier: ${spec}`);
  if (selected !== undefined && command !== match[1]) {
    throw new Error(
      `command must match the unscoped package name: ${match[1]}`,
    );
  }
  return ["run", "--allow-all", `npm:${spec}`, ...args.slice(index)];
}

try {
  const args = translate(Deno.args);
  const child = new Deno.Command("deno", {
    args,
    stdin: "inherit",
    stdout: "inherit",
    stderr: "inherit",
  }).spawn();
  const signals: Deno.Signal[] = ["SIGINT", "SIGTERM", "SIGHUP"];
  const listeners = signals.map((signal) => {
    const forward = () => {
      try {
        child.kill(signal);
      } catch (error) {
        // A signal can race with the child exiting.
        if (!(error instanceof Deno.errors.NotFound)) throw error;
      }
    };
    Deno.addSignalListener(signal, forward);
    return { signal, forward };
  });
  let status: Deno.CommandStatus;
  try {
    status = await child.status;
  } finally {
    for (const { signal, forward } of listeners) {
      Deno.removeSignalListener(signal, forward);
    }
  }
  Deno.exit(status.code);
} catch (error) {
  console.error(
    `npx: ${error instanceof Error ? error.message : String(error)}`,
  );
  console.error(
    "Usage: npx [--yes|-y] [--package=<package>|-p <package>] [--] <command> [args...]",
  );
  console.error(
    "This dock shim supports one registry package; it is not full npx.",
  );
  Deno.exit(1);
}
