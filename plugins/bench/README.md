# bench

Measures cost and delivered quality for implementing the same ticket through multiple approaches.

Each approach is a declarative YAML file in `approaches/`. Adding one requires no code change.

## Commands

- `/bench:run <TICKET>` — run one or more approaches against a ticket
- `/bench:report <TICKET>` — regenerate the aggregate report from stored run data

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

The SDLC adapters are **not yet runnable**: every SDLC entry point writes to its Jira story and
ends at a pull request, and the harness has neither the scratch Jira issue nor the bench-scoped
push guard the design calls for. Both files say so in their header.

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

Allow entries only. The deny list — push, merge, rebase, PR-merge — is a harness boundary and is
not adapter-settable.

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
