# AGENTS.md

Instructions for AI coding agents working in this repository.

## Project

dock is a library of lean, layered CI Docker images published at
`ghcr.io/driftsys/dock`. Each image adds exactly one concern — scripting
foundation, compilation toolchain, or language runtime — so teams pick the
smallest image that covers their pipeline.

Every image ships in two variants:

- **Alpine** (default, untagged) — musl libc, smallest footprint
- **Debian** (`-debian` suffix) — glibc, bookworm-slim base, broader
  compatibility

## Build commands

```bash
just build     # Build all images via docker-bake.hcl
just test      # Run the bash_unit test suite against local images
just lint      # hadolint + shellcheck + dprint check
just fmt       # Format Markdown
just clean     # Remove local build artefacts
```

## Architecture

**Image inheritance tree:**

```text
alpine:3.21
  └── :core              (~32 MB)
      ├── :lint          (~44 MB)   [low prio]
      ├── :rust          (~260 MB)
      │   └── :polyglot  (~382 MB)
      ├── :deno          (~120 MB)
      ├── :node          (~115 MB)
      └── :python        (~55 MB)
```

**Directory layout:**

```text
dock/
├── images/
│   ├── core/
│   ├── rust/
│   ├── deno/
│   ├── node/
│   ├── python/
│   └── polyglot/
├── tests/              # bash_unit test suites
├── scripts/            # shared shell utilities
└── docs/               # documentation
```

Each image directory contains `Dockerfile` (Alpine) and `Dockerfile.debian`
(Debian variant).

**Build system:** `docker-bake.hcl` with registry-based cache (GHCR).
Architectures: `linux/amd64` + `linux/arm64` (QEMU for cross-builds).

**Tag format:** `ghcr.io/driftsys/dock:{image}-{variant?}-{version}`.\
Alpine is the default (no suffix). Debian uses `-debian` suffix.

**Runtime versions** are recorded in `/etc/dock/manifest.json` inside each
image, not in tags.

## Workflow

Follow [CONTRIBUTING.md](CONTRIBUTING.md) for issue model, PR process,
severity/effort/priority, and review flow.

**Agent-specific rules:**

- **Start from the issue.** Read the acceptance criteria and the epic,
  propose an approach, and wait for approval before implementing.
- **Testing.** bash_unit (vendored) is the test framework. Two test layers:
  - _Presence tests_ — verify binaries exist and are on `$PATH`.
  - _Sanity tests_ — verify tools work (version checks, basic invocation).
    CI matrix runs: image × variant.
- **Single PR = Dockerfile + tests + docs.** Every pull request ships
  implementation, tests, and updated documentation together.
- **Commits.** Use Conventional Commits: `feat`, `fix`, `refactor`, `docs`,
  `test`, `chore`. Imperative mood. One commit per PR.
- **Before PR.** Run `just lint` — all must pass with zero warnings.
- **PR review.** After opening a PR, review it and submit findings. Triage
  each finding:
  - **Must fix (`K0`)** — fix immediately before merging.
  - **Should fix (`K1`)** — open a debt issue linking to the PR.
  - **Nice to have (`K2`)** — open a debt issue linking to the PR.\
    Debt issues must link to the PR that surfaced the finding and include
    enough context to understand the problem without reading the PR.

**Issue labels and priority:**

Issue types: `story` (user-facing), `task` (technical), `debt`
(refactor/review finding). Every issue body must start with `Epic: #N`.
Severity: `K0` must-have, `K1` should-fix, `K2` nice-to-have. Effort:
`XS` `S` `M` `L` `XL`. Priority is derived from the K × size matrix:

| K↓ Size→ | XS | S  | M  | L    | XL   |
| -------- | -- | -- | -- | ---- | ---- |
| K0       | P0 | P0 | P0 | P1   | P1   |
| K1       | P0 | P1 | P1 | P2   | drop |
| K2       | P1 | P2 | P2 | drop | drop |

P0 = do now · P1 = do next · P2 = do when convenient · drop = close as
won't-fix.

## Conventions

- **Zero warnings.** No warnings anywhere — hadolint, shellcheck, dprint
  (Markdown), or markdownlint. Fix warnings as they appear; do not silence
  them unless unavoidable, and document the reason.
- **Single RUN layers.** Each `RUN` instruction addresses exactly one
  concern. Chain `apk add` calls within a single `RUN`; do not scatter
  package installs across multiple layers.
- **No CMD/ENTRYPOINT.** Images are toolboxes, not services.
- **OCI labels.** Every image must declare `org.opencontainers.image.*`
  labels: `source`, `revision`, `version`, `created`.
- **Installation priority.** Prefer `apk`/`apt` → official static binaries
  → build from source (last resort).
- **Shell scripts.** All scripts in `scripts/` must pass `shellcheck` with
  zero warnings. Use `#!/usr/bin/env bash` shebang.
- **Markdown.** Format with `dprint`. Line length ≤ 80 characters (except
  tables and code blocks).

## Post-clone setup

Run `./bootstrap` after `git clone` or `git worktree add`. It installs
`git-std` (if needed) and wires up the git hooks (`commit-msg`,
`pre-commit`).

You still need Docker (with BuildKit) and `just` on your `$PATH`.
