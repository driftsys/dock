# :deno

Deno runtime. Inherits all `:core` tools.

## Base

| Variant          | Base                                       |
| ---------------- | ------------------------------------------ |
| Alpine (default) | `ghcr.io/driftsys/dock:core` (build        |
|                  | context)                                   |
| Debian           | `ghcr.io/driftsys/dock:core-debian` (build |
|                  | context)                                   |

## Installed tools

| Tool | Install method      | Purpose                                      |
| ---- | ------------------- | -------------------------------------------- |
| deno | official LTS binary | TypeScript/JavaScript runtime                |
| npx  | TypeScript shim     | Run npm packages via `deno run -A npm:<pkg>` |
| npm  | TypeScript shim     | Delegates supported npm commands to Deno     |

Deno 2.9.3 is downloaded from the official LTS distribution at `dl.deno.land`.
The Alpine build takes bundled glibc libraries from the official `denoland/deno`
image and patches the LTS binary to use those libraries. The version is
controlled by the `DENO_VERSION` build argument.

The current upstream LTS download still reports `stable` in its version banner,
including after `deno upgrade lts`. The selected version follows the upstream
LTS endpoint; the tests verify the supported 2.9 release line.

The Alpine binary resolves its bundled glibc libraries through its patched
RPATH. The image does not set a global `LD_LIBRARY_PATH`, so core tools such as
ripgrep continue to use Alpine's musl libraries.

The `npx` and `npm` shims allow using npm ecosystem tools without installing
Node.js. They delegate to Deno under the hood:

```bash
# Run an npm package executable
npx prettier --check .

# npm shim supports: install, ci, run, test, init
npm install   # → deno install
npm run build # → deno task build
```

## Usage in CI

```yaml
jobs:
  check:
    runs-on: ubuntu-latest
    container: ghcr.io/driftsys/dock:deno
    steps:
      - uses: actions/checkout@v4
      - run: deno lint
      - run: deno fmt --check
      - run: deno test
```

## Build arguments

| Argument       | Default | Description                 |
| -------------- | ------- | --------------------------- |
| `DENO_VERSION` | `2.9.3` | Deno LTS release to install |

## Approximate size

Compressed download size for `linux/amd64`.

| Variant | Size    |
| ------- | ------- |
| Alpine  | ~88 MB  |
| Debian  | ~137 MB |

## npx adapter

The executable `utils/npx.ts` is installed as `/usr/local/bin/npx` with a Deno
shebang. `utils/` holds executable tools shipped in dock images; `scripts/` also
contains build and maintenance scripts.

Supported forms:

```bash
npx prettier@3.5.3 --check .
npx --yes --package=gitlab-ci-local@4.75.0 gitlab-ci-local --preview
npx -y --package gitlab-ci-local@4.75.0 gitlab-ci-local --preview
npx -p @scope/tool@1.2.3 tool "argument with spaces"
```

The second command executes:

```bash
deno run --allow-all npm:gitlab-ci-local@4.75.0 --preview
```

`--yes` and `-y` are accepted and ignored. `--` ends adapter option parsing.
After the first positional argument, every argument is passed unchanged to
Deno's npm executable. Versions, tags, and ranges without whitespace stay in the
npm specifier. The working directory, standard streams, and child exit status
are preserved. SIGINT, SIGTERM, and SIGHUP are forwarded to the child, and the
adapter waits for it to exit.

For explicit package selection, the command must equal the package name without
its scope or version: `@scope/tool@1.2.3` expects `tool`. Explicit command
aliases are unsupported: the command token must match the package name, even
when its binary has another name. Deno may resolve a sole binary whose name
differs from the package. The adapter does not inspect package metadata or
select among multiple executables.

This is a limited adapter, not full npx compatibility. It rejects missing
values, multiple package selections, unsupported adapter flags, and non-registry
specifiers such as URLs or local paths. Shell commands (`-c`), workspace
selection, npm configuration flags, and npm's local executable lookup are
unsupported. Use Deno directly for its runtime options.

The image contains no Node.js or npm runtime. Its separate `npm` command is also
a dock adapter; it is not npm itself.

## npm adapter

`utils/npm.ts` is installed as executable `/usr/local/bin/npm`. It supports a
limited npm command vocabulary and runs Deno. It does not provide the npm
runtime, a standalone `node` command, or full npm compatibility.

| Command                          | Deno behavior                                                    |
| -------------------------------- | ---------------------------------------------------------------- |
| `install`, `i`, `add`            | Install dependencies, or add registry packages to `package.json` |
| `install -g`, `install --global` | Install one registry package as a Deno launcher                  |
| `uninstall`, `remove`, `rm`      | Remove named dependencies from `package.json`                    |
| `uninstall -g`                   | Remove one globally installed launcher                           |
| `ci`, `clean-install`            | `deno install --frozen`                                          |
| `run`, `run-script`              | `deno task`                                                      |
| `test`, `t`                      | `deno task test`                                                 |
| `exec`                           | Run one registry package with Deno, using the npx adapter forms  |
| `init`                           | Scaffold a Deno project, optionally in one directory             |
| `help`, `--help`, `-h`           | Describe the supported adapter subset                            |

Local installation accepts multiple registry packages, including scopes,
versions, tags, and ranges without whitespace. `--save-dev`/`-D` adds packages
to `devDependencies`; it requires package arguments. `--omit=dev` (or
`--omit dev`) selects production dependencies for install or ci. Development and
production flags cannot be combined, and neither applies to global mode. Local
removal accepts bare package names, including scopes, without versions.

```bash
npm install is-number@7.0.0 is-odd@3.0.1
npm install --save-dev picocolors@1.1.1
npm install --omit=dev
npm uninstall is-number is-odd
npm install --global gitlab-ci-local@4.75.0
gitlab-ci-local --preview
npm uninstall -g gitlab-ci-local
```

Global commands use `/usr/local` as the installation root; launchers go in
`/usr/local/bin`, which is already on PATH. `--prefix <directory>` or
`--prefix=<directory>` overrides that root. The launcher name is the package
name without scope or version. Installation uses `--allow-all` so that tools can
run unattended in CI. The names `deno`, `npm`, and `npx` are reserved. No
overwrite flag is supported; Deno reports existing-launcher conflicts. Other
runtime users need a writable prefix with its `bin/` directory on PATH. Only one
global package is accepted per command.

For local commands, `--prefix` selects the child's working directory instead. It
may appear before the command or among its adapter options. Without it, the
adapter inherits the working directory. Deno task then applies its own
project-directory semantics. Multiple prefixes and missing values are errors.

```bash
npm --prefix ./frontend run build -- --watch "argument with spaces"
npm run --if-present lint
npm test -- --filter "some test"
npm exec --yes --package=gitlab-ci-local@4.75.0 gitlab-ci-local --preview
```

`run` and `test` accept `--if-present`. Use `--` to separate task arguments from
adapter options; arguments after it are forwarded unchanged. A bare `npm run`
lists tasks. Package execution follows the npx adapter's scoped name and option
boundaries. `init` retains Deno scaffolding; `-y`/`--yes` are accepted and
ignored, not npm package initializer execution.

Deno tasks read `package.json` scripts. A script such as
`"start": "node app.cjs"` can run through Deno's Node compatibility when invoked
with `npm run start`, without installing Node.js. This does not guarantee
compatibility with every Node program. Use the `:node` image when the actual
Node.js runtime is required.

`ci` retains the old adapter's Deno frozen-lockfile behavior. It does not
promise npm's `package-lock.json` validation, clean `node_modules` install, or
lifecycle ordering. npm registry/configuration flags, workspaces, publish,
audit, local paths, URLs, and unknown flags are unsupported. Standard streams,
argument boundaries, and child exit codes are preserved. SIGINT, SIGTERM, and
SIGHUP are forwarded; the adapter waits for child cleanup and returns the
child's actual status, including custom signal-handler codes.
