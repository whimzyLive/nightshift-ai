# bench

Measures cost and delivered quality for implementing the same ticket through multiple approaches.

Each approach is a declarative YAML file in `approaches/`. Adding one requires no code change.

## Commands

- `/bench:run <TICKET>` — run one or more approaches against a ticket
- `/bench:report <TICKET>` — regenerate the aggregate report from stored run data
- `/bench:cleanup <TICKET>` — close draft PRs, delete bench branches, worktrees and scratch issues

## Cost

Every cell is a **cold** `claude -p` session, deliberately: cells sharing a warm cache in one live
session would make whichever approach ran second look cheaper purely from cache reuse, so the
comparison would measure run order rather than approach.

That correctness is paid for in quota — a cold session re-reads its system prompt, plugin
definitions and CLAUDE.md at full rate every time. `benchlib/quota.py` forecasts a sweep before it
starts, refuses to begin above a cost threshold without `--acknowledge-cost`, and caps cells per
sweep outright. The cap is not clearable by acknowledgement: acknowledging a number you did not
intend to produce is not consent.

## Pipeline

`resolve` → `provision` → `execute` → `measure` → `grade` → `report`

Each stage reads and writes files under `docs/benchmarks/<TICKET>/<CELL>/<RUN_ID>/`, so any stage
can be re-run standalone without repeating the ones before it, and a cell can be repeated without
overwriting its earlier runs.

## Approaches

| File                                   | What it measures                                  |
| -------------------------------------- | ------------------------------------------------- |
| `opus.yaml`                            | Direct Opus, no plugins at all — the control arm  |
| `superpowers.yaml`                     | superpowers skills at a pinned version            |
| `speckit.yaml`                         | GitHub spec-kit, pinned to a release tag          |
| `sdlc-0.44.0.yaml`, `sdlc-0.45.4.yaml` | the SDLC plugin at two versions, for before/after |

## Real Jira, real draft PRs

An approach that writes to Jira sets `scratch_ticket: true`. Provisioning then clones the source
ticket into a **per-cell** issue labelled `bench-run`, and the session works against that: its
comments, transitions and pull request land on a real, visible ticket while the source ticket is
never written to.

Per cell, not per sweep, and that is the load-bearing part. The SDLC plugin derives its git branch
from the story key, and its playbook reuses an existing `feat/<KEY>` branch rather than creating a
duplicate — so two cells sharing one issue would share one branch, and the second would check out
the first's finished work and measure nothing.

Pushes are policed by a `PreToolUse` guard (`scripts/bench_guard.py`), registered per worktree:

|         |                                                                                                |
| ------- | ---------------------------------------------------------------------------------------------- |
| Allowed | this cell's `bench/` branch, anything under `bench/`, `feat\|fix/<SCRATCH-KEY>`                |
| Denied  | every other ref, `main`/`master`/`develop` unconditionally, force-push, `--delete`, `--mirror` |
| Denied  | `gh pr create` without `--draft`, `gh pr ready`, `gh pr merge`, merge endpoints via `gh api`   |
| Denied  | any guarded verb behind `&&`, `;`, `\|` or `$(…)` — unparseable means refused, not guessed     |

It fails closed: a missing or malformed guard config denies every guarded verb, as does any
unexpected exception. Deny reasons are returned to the session, so `gh pr create` without `--draft`
comes back as an instruction to retry rather than an unexplained failure — which is why the SDLC
adapter's prompt does not mention drafts. `/sdlc:auto` parses its whole `$ARGUMENTS` as the story
key, so an appended instruction would be swallowed into the key.

Merge, rebase, force-push and `gh pr ready` remain blunt denies **as well**, because deny rules
resolve before any hook — those hold even if the guard fails to load.

Clean up with `/bench:cleanup <TICKET>`, which is dry-run by default.

## Plugin isolation

Every adapter must declare the exact plugin set it loads:

```yaml
plugins:
  enable: [sdlc@nightshift] # or `enable: []` for an approach that loads none
```

This is required rather than optional because a bench worktree is a checkout of the subject repo,
so it inherits that repo's `.claude/settings.json` and the operator's `~/.claude/settings.json`.
Left alone, a cell labelled _"Direct Opus, no framework"_ runs with whatever the operator has
enabled — on the machine this was built on, that meant the SDLC plugin loaded and superpowers'
SessionStart hook injecting _"You have superpowers"_ into the session meant to have none.

`provision.py` therefore writes an **exhaustive** `enabledPlugins` map into the worktree's
`settings.local.json`: true for the declared set, explicitly false for every other installed
plugin. That file overrides both the repository and user layers.

Hooks are the part this cannot fix. Hooks merge additively across settings layers with no override
key, so any hook in the user or repository settings runs in every cell. Plugin-supplied hooks
disappear with their plugins; whatever remains is recorded per run as `ambient_hooks` and printed
in the report, because a hook that rewrites shell commands or injects text moves the number being
measured.

An adapter may also request the tools its approach genuinely needs:

```yaml
permissions:
  - Bash(acli:*)
```

Allow entries only. The deny list and the push guard are harness boundaries and are not
adapter-settable — an adapter that could write them could un-deny `gh pr merge`.

## Version pinning

An adapter may pin the plugin version it measures:

```yaml
id: sdlc
version:
  plugin: sdlc@nightshift
  version: 0.44.0
```

Cells are then filed as `sdlc@0.44.0`, so two versions of one tool compare side by side in a single
report. `--baseline sdlc@0.44.0` adds a delta table.

This exists because Claude Code resolves a plugin's version **per project path**, not per branch —
so running two branches measures the same version twice. `execute.py` pins the cell's worktree path
in `~/.claude/plugins/installed_plugins.json` before the session starts and restores that file on
every exit path, including failure; `measure.py` then verifies from the session transcript which
version actually loaded and fails the cell if it disagrees with the pin.

Cached versions are reference-counted and swept when unreferenced, so a pin whose target is gone
aborts at preflight rather than silently measuring whatever is installed.

## Reading a result

A single run per cell has no noise floor. Repeat cells with different `--run-id` values; the report
prints the observed spread and warns that smaller deltas are indistinguishable from sampling
variation.

Design: `docs/superpowers/specs/2026-07-28-bench-harness-design.md`
