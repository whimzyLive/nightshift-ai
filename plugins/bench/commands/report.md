---
description: Regenerate the aggregate benchmark report for a ticket from stored run data
---

Regenerate the comparison report without re-running anything.

This command receives `${CLAUDE_PLUGIN_ROOT}` natively from the harness — use it directly.

## Arguments

- `<TICKET>` — required

## Steps

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/report.py" \
  --ticket <TICKET> --out docs/benchmarks/<TICKET>/report.md
```

Show the rendered table. If any row is flagged `RECONCILIATION FAILED`, say so explicitly and state
that the row is excluded from aggregate conclusions.
