#!/usr/bin/env -S deno run --allow-run
// A limited npm command adapter. Package execution uses Deno, not Node.js.

const HELP = `Usage: npm [--prefix <directory>] <command> [args...]
Supported: install/i/add, uninstall/remove/rm, ci/clean-install,
run/run-script, test/t, exec, init, help.
install: [-g|--global] [-D|--save-dev] [--omit=dev] [packages...]
uninstall: [-g|--global] <packages...>
run/test: [--if-present] [--prefix <directory>] [task] [-- args...]
exec: [--yes|-y] [--package=<package>|-p <package>] [--] <command> [args...]
Global commands accept one package and use /usr/local by default;
--prefix selects a different global root or a local working directory.
ci uses Deno's frozen lockfile behavior; init scaffolds a Deno project.
This dock adapter is not full npm. Unsupported flags are rejected.`;

function value(args: string[], option: string): string {
  const result = args.shift();
  if (!result || result.startsWith("-")) {
    throw new Error(`missing value for ${option}`);
  }
  return result;
}

function packageName(spec: string, version = true): string {
  const match =
    /^(?:@[a-z0-9_][a-z0-9._-]*\/)?([a-z0-9_][a-z0-9._-]*)(?:@([^\s/@]+))?$/
      .exec(spec);
  if (!match || (!version && match[2] !== undefined)) {
    throw new Error(`unsupported package specifier: ${spec}`);
  }
  return match[1];
}

function translate(
  input: string[],
): { args: string[]; cwd?: string } | undefined {
  const rest = [...input];
  let prefix: string | undefined;
  const readPrefix = (arg: string) => {
    if (arg !== "--prefix" && !arg.startsWith("--prefix=")) return false;
    if (prefix !== undefined) {
      throw new Error("multiple prefixes are unsupported");
    }
    prefix = arg === "--prefix" ? value(rest, arg) : arg.slice(9);
    if (!prefix) throw new Error("missing value for --prefix");
    return true;
  };
  while (rest[0] === "--prefix" || rest[0]?.startsWith("--prefix=")) {
    readPrefix(rest.shift()!);
  }
  const supplied = rest.shift();
  if (!supplied) throw new Error("missing command");
  const aliases: Record<string, string> = {
    i: "install",
    add: "install",
    remove: "uninstall",
    rm: "uninstall",
    "clean-install": "ci",
    "run-script": "run",
    t: "test",
  };
  const command = aliases[supplied] ?? supplied;
  const commands = [
    "install",
    "uninstall",
    "ci",
    "run",
    "test",
    "exec",
    "init",
  ];
  if (
    command === "help" &&
    (rest.length > 1 ||
      (rest.length === 1 && !commands.includes(aliases[rest[0]] ?? rest[0])))
  ) {
    throw new Error("unsupported help topic");
  }
  if (
    command === "help" ||
    ((command === "--help" || command === "-h") && !rest.length) ||
    (commands.includes(command) && rest.length === 1 &&
      (rest[0] === "--help" || rest[0] === "-h"))
  ) {
    console.log(HELP);
    return;
  }
  const local = (args: string[]) => ({ args, cwd: prefix });
  if (["install", "uninstall", "ci"].includes(command)) {
    let global = false;
    let dev = false;
    let prod = false;
    let options = true;
    const packages: string[] = [];
    while (rest.length) {
      const arg = rest.shift()!;
      if (options && arg === "--") {
        options = false;
        continue;
      }
      if (options && readPrefix(arg)) continue;
      if (options && (arg === "-g" || arg === "--global")) {
        global = true;
        continue;
      }
      if (
        options && (arg === "-D" || arg === "--save-dev") &&
        command === "install"
      ) {
        dev = true;
        continue;
      }
      if (
        options && (arg === "--omit" || arg.startsWith("--omit=")) &&
        command !== "uninstall"
      ) {
        const omit = arg === "--omit" ? value(rest, arg) : arg.slice(7);
        if (omit !== "dev") throw new Error("only --omit=dev is supported");
        prod = true;
        continue;
      }
      if (options && arg.startsWith("-")) {
        throw new Error(`unsupported option: ${arg}`);
      }
      packageName(arg, command !== "uninstall");
      packages.push(arg);
    }
    if (command === "ci") {
      if (global || packages.length) {
        throw new Error("ci accepts no packages or global mode");
      }
      return local(["install", "--frozen", ...(prod ? ["--prod"] : [])]);
    }
    if (dev && (prod || global || !packages.length)) {
      throw new Error(
        "--save-dev requires local packages and conflicts with --omit=dev",
      );
    }
    if (global) {
      if (packages.length !== 1 || prod) {
        throw new Error(
          "global commands require one package and no dependency flags",
        );
      }
      const name = packageName(packages[0], command !== "uninstall");
      if (["deno", "npm", "npx"].includes(name)) {
        throw new Error(`reserved executable name: ${name}`);
      }
      const root = prefix ?? "/usr/local";
      return {
        args: command === "install"
          ? [
            "install",
            "--global",
            "--allow-all",
            "--root",
            root,
            "--name",
            name,
            `npm:${packages[0]}`,
          ]
          : ["uninstall", "--global", "--root", root, name],
      };
    }
    if (command === "uninstall") {
      if (!packages.length) throw new Error("missing package to uninstall");
      return local(["uninstall", "--package-json", ...packages]);
    }
    return local([
      "install",
      ...(packages.length ? ["--package-json"] : []),
      ...(dev ? ["--dev"] : []),
      ...(prod ? ["--prod"] : []),
      ...packages.map((spec) => `npm:${spec}`),
    ]);
  }
  if (command === "run" || command === "test") {
    let optional = false;
    let task = command === "test" ? "test" : undefined;
    const forwarded: string[] = [];
    while (rest.length) {
      const arg = rest.shift()!;
      if (arg === "--") {
        if (task === undefined) task = rest.shift();
        forwarded.push(...rest);
        break;
      }
      if (readPrefix(arg)) continue;
      if (arg === "--if-present") {
        optional = true;
        continue;
      }
      if (arg.startsWith("-")) {
        throw new Error(
          `unsupported option: ${arg}; use -- before task arguments`,
        );
      }
      if (task === undefined) task = arg;
      else forwarded.push(arg);
    }
    if (!task && (optional || forwarded.length)) {
      throw new Error("missing task name");
    }
    if (task?.startsWith("-")) throw new Error("invalid task name");
    return local([
      "task",
      ...(optional ? ["--if-present"] : []),
      ...(task ? [task] : []),
      ...forwarded,
    ]);
  }
  if (command === "exec") {
    let selected: string | undefined;
    while (rest.length) {
      const arg = rest[0];
      if (arg === "--") {
        rest.shift();
        break;
      }
      if (arg === "--yes" || arg === "-y") {
        rest.shift();
        continue;
      }
      if (arg === "--prefix" || arg.startsWith("--prefix=")) {
        rest.shift();
        readPrefix(arg);
        continue;
      }
      if (arg === "--package" || arg === "-p" || arg.startsWith("--package=")) {
        rest.shift();
        if (selected !== undefined) {
          throw new Error("multiple package selections are unsupported");
        }
        selected = arg.startsWith("--package=")
          ? arg.slice(10)
          : value(rest, arg);
        if (!selected) throw new Error("missing package value");
        continue;
      }
      if (arg.startsWith("-")) throw new Error(`unsupported option: ${arg}`);
      break;
    }
    const executable = rest.shift();
    if (!executable) throw new Error("missing package or command");
    const spec = selected ?? executable;
    const name = packageName(spec);
    if (selected !== undefined && executable !== name) {
      throw new Error(`command must match the unscoped package name: ${name}`);
    }
    return local(["run", "--allow-all", `npm:${spec}`, ...rest]);
  }
  if (command === "init") {
    const directories: string[] = [];
    while (rest.length) {
      const arg = rest.shift()!;
      if (readPrefix(arg) || arg === "-y" || arg === "--yes") continue;
      if (arg.startsWith("-")) throw new Error(`unsupported option: ${arg}`);
      directories.push(arg);
    }
    if (directories.length > 1) {
      throw new Error("init accepts at most one directory");
    }
    return local(["init", ...directories]);
  }
  throw new Error(`unsupported command: ${supplied}`);
}

try {
  const plan = translate(Deno.args);
  if (plan) {
    const child = new Deno.Command("deno", {
      ...plan,
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
  }
} catch (error) {
  console.error(
    `npm: ${error instanceof Error ? error.message : String(error)}`,
  );
  console.error(
    "Run npm --help for the supported subset; this is not full npm.",
  );
  Deno.exit(1);
}
