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

### Estimating spend

For each approach, state:

- the number of measured sessions this approach will run (one session per cell in the pipeline)
- that three independent graders evaluate the result per cell
- that a prior measured direct-Opus session on this machine cost approximately $0.16 for a trivial prompt
- that real story-sized prompts are significantly larger and spending is genuinely unpredictable

Present a cost range with its basis, and say plainly that the figure is an estimate, not a guarantee. If the founder wants a firmer number, the pilot cell exists precisely to produce one.

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

   **On failure:** Abort this approach's cell, record the error, and continue to the next approach. Do not retry or skip to measure — the worktree is the evidence of what happened.

3. Execute.

   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/execute.py" \
     --cell docs/benchmarks/<TICKET>/<APPROACH>/cell.json \
     --story docs/benchmarks/<TICKET>/story.json \
     --adapter "${CLAUDE_PLUGIN_ROOT}/approaches/<APPROACH>.yaml" \
     --out docs/benchmarks/<TICKET>/<APPROACH>/result.json
   ```

   **On failure:** Abort this approach's cell, record the error, and continue to the next approach. Do not retry — this stage spends money. Never auto-retry without explicit founder confirmation.

4. Run tests inside the cell's worktree to capture test evidence for graders.

   Load the test command from the project's `.claude/project/project-context.md` file (key: "Typecheck / Test"), or use an empty command if not configured. Run this command with the worktree as the working directory, and redirect combined stdout and stderr to the cell's artifacts directory (read the `artifacts` path from the cell's cell.json):

   ```bash
   cd <WORKTREE> && <TEST_COMMAND> > "<CELL_ARTIFACTS>/tests.txt" 2>&1 || true
   ```

   The destination is the cell's artifacts directory, which provision.py has already created at an absolute path outside the worktree — so test evidence survives worktree removal. The `|| true` ensures this step does not fail the cell even if tests fail — a failing test suite is exactly the evidence the grader needs. Continue regardless.

5. Measure. A non-zero exit means reconciliation failed — report it, do not hide it. Reconciliation failure does NOT stop the cell; continue to grading.

   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/measure.py" \
     --cell docs/benchmarks/<TICKET>/<APPROACH>/cell.json \
     --result docs/benchmarks/<TICKET>/<APPROACH>/result.json \
     --adapter "${CLAUDE_PLUGIN_ROOT}/approaches/<APPROACH>.yaml" \
     --out docs/benchmarks/<TICKET>/<APPROACH>/run.json
   ```

6. Grade.

   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/grade.py" \
     --cell docs/benchmarks/<TICKET>/<APPROACH>/cell.json \
     --story docs/benchmarks/<TICKET>/story.json \
     --out docs/benchmarks/<TICKET>/<APPROACH>/grades.json
   ```

   **On failure:** Abort this approach's cell, record the error, and continue to the next approach. Do not retry — this stage spends money (grader invocations). Never auto-retry without explicit founder confirmation.

Then render the report once, across every approach that ran:

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/report.py" \
  --ticket <TICKET> --out docs/benchmarks/<TICKET>/report.md
```

Report the table to the founder. Never merge a bench branch. Never delete a worktree that failed —
its transcript is the evidence.
