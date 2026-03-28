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
- **[dprint]** — Markdown formatter

```bash
git clone https://github.com/driftsys/dock.git
cd dock
just build
```

[just]: https://github.com/casey/just
[dprint]: https://dprint.dev

## Architecture

See [AGENTS.md](AGENTS.md) for the full image catalog, inheritance tree, and
directory layout.

## Testing

```bash
just test    # Run the full bash_unit test suite
just lint    # hadolint + shellcheck + dprint check
```

Tests live in `tests/`. Each image has a presence test (binaries exist and
are on `$PATH`) and a sanity test (tools execute correctly).

bash_unit is vendored in `tests/bash_unit`. Do not upgrade it without
updating the vendored copy.
