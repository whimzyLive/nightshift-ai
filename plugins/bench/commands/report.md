---
description: Regenerate the aggregate benchmark report for a ticket from stored run data
---

Regenerate the comparison report without re-running anything.

This command receives `${CLAUDE_PLUGIN_ROOT}` natively from the harness — use it directly.

## Arguments

- `<TICKET>` — required
- `--baseline <cell>` — optional, e.g. `sdlc@0.44.0`. Adds a table differencing every other cell
  against this one. Use it for before/after comparisons of the same tool at two versions.

## Steps

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/report.py" \
  --ticket <TICKET> [--baseline <CELL>] --out docs/benchmarks/<TICKET>/report.md
```

Show the rendered table. If any row is flagged `RECONCILIATION FAILED`, say so explicitly and state
that the row is excluded from aggregate conclusions.

Two more row states to surface rather than summarise away:

- `WRONG VER` — the version pin did not take, so the row measures a version other than the one its
  cell claims. The Version column shows what actually ran. A version comparison that includes this
  row answers the wrong question.
- A `?` in the Version column — the pin could not be confirmed from the transcript because that
  plugin announces no root. Say that the label rests on the declaration alone.

If a _Repeat runs_ section is present, quote the observed spread alongside any delta and state
plainly whether the delta clears it. If that section is absent, every cell ran once: say that the
sweep has no noise floor and cannot support a claim that one version is cheaper than another.
