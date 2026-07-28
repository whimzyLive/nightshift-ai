---
description: Run one or more benchmark approaches against a ticket and report measured cost and quality
---

Run the benchmark pipeline for a ticket.

This command receives `${CLAUDE_PLUGIN_ROOT}` natively from the harness — use it directly.

## Arguments

- `<TICKET>` — required, e.g. `NA-68`
- `--approaches <ids>` — comma-separated, default `opus`
- `--repo <path>` — default the current repository
- `--run-id <id>` — default a short timestamp-free counter supplied by the caller

## Safety

Runs execute against the real repository and cost real money. Before dispatching, confirm with the founder:

- the ticket key and the approaches to run
- that branches will be created under `bench/` and never merged
- the estimated spend

Do not proceed without that confirmation.

## Steps

For each approach, in the order given:

1. Resolve the ticket.

   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/resolve.py" \
     --key <TICKET> --repo <REPO> --out docs/benchmarks/<TICKET>/story.json
   ```

2. Provision a worktree.

   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/provision.py" \
     --story docs/benchmarks/<TICKET>/story.json \
     --approach <APPROACH> --run-id <RUN_ID> --repo <REPO> \
     --out docs/benchmarks/<TICKET>/<APPROACH>/cell.json
   ```

3. Execute.

   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/execute.py" \
     --cell docs/benchmarks/<TICKET>/<APPROACH>/cell.json \
     --story docs/benchmarks/<TICKET>/story.json \
     --adapter "${CLAUDE_PLUGIN_ROOT}/approaches/<APPROACH>.yaml" \
     --out docs/benchmarks/<TICKET>/<APPROACH>/result.json
   ```

4. Measure. A non-zero exit means reconciliation failed — report it, do not hide it.

   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/measure.py" \
     --cell docs/benchmarks/<TICKET>/<APPROACH>/cell.json \
     --result docs/benchmarks/<TICKET>/<APPROACH>/result.json \
     --adapter "${CLAUDE_PLUGIN_ROOT}/approaches/<APPROACH>.yaml" \
     --out docs/benchmarks/<TICKET>/<APPROACH>/run.json
   ```

5. Grade.

   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/grade.py" \
     --cell docs/benchmarks/<TICKET>/<APPROACH>/cell.json \
     --story docs/benchmarks/<TICKET>/story.json \
     --out docs/benchmarks/<TICKET>/<APPROACH>/grades.json
   ```

Then render the report once, across every approach that ran:

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/report.py" \
  --ticket <TICKET> --out docs/benchmarks/<TICKET>/report.md
```

Report the table to the founder. Never merge a bench branch. Never delete a worktree that failed —
its transcript is the evidence.
