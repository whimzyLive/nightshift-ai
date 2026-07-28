# bench

Measures cost and delivered quality for implementing the same ticket through multiple approaches.

Each approach is a declarative YAML file in `approaches/`. Adding one requires no code change.

## Commands

- `/bench:run <TICKET>` — run one or more approaches against a ticket
- `/bench:report <TICKET>` — regenerate the aggregate report from stored run data

## Pipeline

`resolve` → `provision` → `execute` → `measure` → `grade` → `report`

Each stage reads and writes files under `docs/benchmarks/<TICKET>/`, so any stage can be re-run
standalone without repeating the ones before it.

Design: `docs/superpowers/specs/2026-07-28-bench-harness-design.md`
