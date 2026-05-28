# Design: github-cli and gitlab-cli Skills

## Context

MCP servers for GitHub, GitLab, and Git add tool-manifest overhead
to every session. The `gh` and `glab` CLIs cover the same operations
with zero manifest cost and are already installed/authenticated.

**Decision:** Disable GitHub, GitLab, and Git MCPs. Compensate with
two reusable skills that teach agents how to use the CLIs effectively.

## Goals

- Replace MCP-based GitHub/GitLab interactions with CLI equivalents
- Minimize per-session token cost (skills load on demand, not always)
- Cover all common operations: issues, PRs/MRs, CI/CD, releases,
  repo management
- Include bootstrap/recovery (install CLI, authenticate)
- Include `gh api`/`glab api` REST fallback for uncovered endpoints

## Non-goals

- GraphQL API patterns (REST covers 95% of CLI use cases)
- Replacing Context7 MCP (no CLI equivalent, kept)
- Project-specific GitHub/GitLab rules (belong in AGENTS.md)

## Architecture

Two separate skills, one per platform. Each follows the existing
expert-skill pattern (`rust-expert`, `kotlin-expert`): single
self-contained SKILL.md, ~80-100 lines.

Installed alongside existing skills at:

```text
~/.config/opencode/superpowers/skills/
  github-cli/
    SKILL.md
  gitlab-cli/
    SKILL.md
```

**Why separate:** A project is almost always GitHub OR GitLab, not
both. Separate skills mean you only load the platform you need.

## Skill Structure (both skills)

### 1. Frontmatter

YAML with `name` and `description`. Description starts with
"Use when..." and lists triggering conditions only (no workflow
summary per CSO rules).

### 2. Overview

One-line core principle: prefer CLI over MCP/curl. Fall back to
`{cli} api` for anything not covered by subcommands.

### 3. Bootstrap

```text
1. Check CLI installed   -> offer to install via brew if missing
2. Check auth status     -> offer to run auth login if unauthenticated
```

Quick, recoverable. Two commands max.

### 4. Core Patterns

#### Output Strategy

- `--json` + `--jq` for lists and field selection (fewer output
  tokens)
- Plain text for single-item reads where output is already compact
- Note: `gh` uses `--json field --jq expr` while `glab` uses
  `--output json` piped to `jq`

#### Issues & PRs/MRs

Common CRUD operations: create, list, view, edit, close.
PR-specific: review, approve, merge.
Emphasis on `--json` for list operations.

#### CI/CD

- GitHub: `gh run list`, `gh run view`, `gh run watch`
- GitLab: `glab ci list`, `glab ci view`, `glab ci trace`

#### Releases & Tags

`{cli} release` create/list/view patterns.

#### API Fallback (REST only)

- `{cli} api {endpoint}` for anything subcommands don't cover
- Pagination: `--paginate`
- Field selection: `--jq`
- Discovery: `{cli} api /repos/{owner}/{repo}` or
  `{cli} api /projects/:id`

### 5. Quick Reference

Table mapping common tasks to exact one-liner commands.
~10-12 rows covering the most frequent operations.

### 6. Common Mistakes

Table of pitfalls specific to each platform:

**github-cli:**

| Mistake                        | Fix                                      |
| ------------------------------ | ---------------------------------------- |
| Using MCP/curl when `gh` works | Always try `gh` subcommand first         |
| `gh pr list` without `--json`  | Use `--json number,title --jq` for lists |
| Missing auth scope             | `gh auth refresh -s scope`               |

**gitlab-cli:**

| Mistake                      | Fix                                         |
| ---------------------------- | ------------------------------------------- |
| Using `--json` (gh syntax)   | `glab` uses `--output json` pipe to `jq`    |
| PR terminology               | GitLab uses MR (merge request)              |
| Project path vs ID confusion | Use path; `glab api` needs URL-encoded path |

### 7. Boundaries

Each skill delegates to the other for the wrong platform.
Neither covers git operations (plain `git` via Bash is sufficient).

## Token Budget

Target: ~90 lines per skill, matching `rust-expert` (86 lines)
and `kotlin-expert` (81 lines).

Estimated cost per load: ~1200-1500 tokens. This is paid only
when the skill is invoked, not every session.

Compared to MCP manifests:

- GitHub MCP: ~20+ tool definitions loaded every session
- GitLab MCP: ~55 tool definitions loaded every session
- Git MCP: ~12 tool definitions loaded every session

Net savings: significant, especially for sessions that don't
touch GitHub/GitLab at all.

## Testing Strategy

Per writing-skills process (TDD for skills):

1. **RED:** Run baseline scenarios without skills — verify agent
   defaults to MCP or curl instead of CLI
2. **GREEN:** Add skills, re-run — verify agent uses `gh`/`glab`
3. **REFACTOR:** Identify gaps (missing commands, wrong flags) and
   iterate

Pressure scenarios:

- "Create a PR" without specifying how
- "Check CI status" on a GitHub project
- "List open issues with label X" on a GitLab project
- CLI not installed — does agent offer to install?
- Auth expired — does agent recover?
