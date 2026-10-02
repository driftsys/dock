# Contributing to dock

For org-wide guidelines — AI policy, commit messages, pull request workflow,
code review, issue model, and documentation style — see the
[driftsys contributing guide][org-contributing] and [process][org-process].

This file covers what is specific to the dock repository.

[org-contributing]: https://github.com/driftsys/.github/blob/main/CONTRIBUTING.md
[org-process]: https://github.com/driftsys/.github/blob/main/PROCESS.md

## Reporting issues

Open bugs and feature requests at <https://github.com/driftsys/dock/issues>.

## Dev setup

You need:

- **Docker** with BuildKit / `docker buildx` support
- **[just]** — command runner
- **[prim]** — repository formatter and linter
- **[git-std]** — commit validation and git hooks

```bash
git clone https://github.com/driftsys/dock.git
cd dock
./bootstrap      # installs git-std, wires git hooks
just build
```

[just]: https://github.com/casey/just
[prim]: https://github.com/driftsys/prim
[git-std]: https://github.com/driftsys/git-std

## Architecture

See [AGENTS.md](AGENTS.md) for the full image catalog, inheritance tree, and
directory layout.

## Testing

```bash
just test        # Run the image bash_unit test suite
just test-health # Check the health workflow without Docker (requires yq v4)
just lint        # hadolint + shellcheck + prim formatting and lint
```

Tests live in `tests/`. Each image has a presence test (binaries exist and are
on `$PATH`) and a sanity test (tools execute correctly).

The weekly health workflow tests published images. Its matrix uses build target
names: unsuffixed targets select `-alpine` tags, and `-debian` targets select
Debian tags. Python and polyglot use only their `-debian` targets. The pull step
and test runner must select the same tag.

`just test-health` checks that every scheduled target is accepted by the runner
and that the workflow pulls the tag the runner tests. It uses Docker recorders
and requires [mikefarah/yq v4][yq]. CI runs this check without building images.

[yq]: https://github.com/mikefarah/yq

bash_unit is vendored in `tests/bash_unit`. Do not upgrade it without updating
the vendored copy.

Use `just fmt` to format repository files. Prim uses its non-strict defaults; do
not add strict Markdown glob mappings or stricter rule overrides. CI validates
pull request commits with `git std lint --range BASE..HEAD`.
