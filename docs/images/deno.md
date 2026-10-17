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
| npm  | shell shim          | Delegates supported npm commands to Deno     |

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
a dock shim; it is not npm itself.
