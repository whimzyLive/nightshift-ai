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
