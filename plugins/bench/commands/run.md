---
description: Run one or more benchmark approaches against a ticket and report measured cost and quality
---

Run the benchmark pipeline for a ticket.

This command receives `${CLAUDE_PLUGIN_ROOT}` natively from the harness — use it directly.

## Arguments

- `<TICKET>` — required, e.g. `NA-68`
- `--approaches <ids>` — comma-separated, default `opus`. An id names an adapter file in `approaches/`
- `--repo <path>` — default the current repository
- `--run-id <id>` — default a short timestamp-free counter supplied by the caller
- `--baseline <cell>` — optional, passed through to the report: difference every row against this one

## Comparing versions of the same tool

An adapter may pin the plugin version it measures:

```yaml
id: sdlc
version:
  plugin: sdlc@nightshift # the installed-plugin key
  version: 0.44.0 # a version directory present in the plugin cache
```

Two adapters differing only in that block give you a before/after. Cells are filed under `<id>@<version>` — `sdlc@0.44.0` and `sdlc@0.45.4` — which namespaces the branch, worktree, artifacts and report row so neither run overwrites the other.

**Why a pin is needed at all:** Claude Code resolves a plugin's version per _project path_, not per branch or per commit. `.claude/settings.json` enables plugins by name only. Running two branches therefore measures the same version twice. `execute.py` pins the cell's worktree path in `~/.claude/plugins/installed_plugins.json` before the session starts, and restores that file afterwards on every exit path including failure.

Three things to know before relying on it:

- **The pin is verified, not trusted.** `measure.py` recovers the version the session actually loaded from its transcript and compares. A disagreement fails the cell and renders as `WRONG VER`, with the Version column showing what really ran.
- **Cached versions get garbage-collected.** The cache reference-counts versions and sweeps unreferenced ones. If the version you want is gone, `execute.py` aborts at preflight and lists what remains — it never silently falls through to whatever is installed.
- **Not every plugin announces its root**, so some pins cannot be independently confirmed. Those render with `?` and rest on the declaration alone.

Approaches that are not plugins (direct Opus) omit the block entirely and are filed under their bare id.

## Establishing a noise floor

Run the same cell more than once with different `--run-id` values. Each run keeps its own artifacts, and the report prints the observed spread plus a warning that any delta smaller than it is indistinguishable from sampling variation. **A single run per cell cannot support a claim that one version is cheaper than another** — say so when reporting such a sweep.

## Safety

Runs execute against the real repository and consume real capacity. Before dispatching, confirm with the founder:

- the ticket key and the approaches to run
- that branches will be created under `bench/` and never merged
- the expected consumption (below)

### Confirming expected consumption

**What the scarce resource actually is depends on how `claude` authenticates on this machine.** `execute.py` records that per run as `billing_mode` and the report states it:

- **`subscription`** — no API key is in play. **No per-run charge is incurred; no money leaves an account.** The scarce resource is **rate-limit budget**, not dollars. A large sweep can exhaust the operator's window and cut a session off mid-run, which the harness marks as a `CUT OFF` cell.
- **`api`** — an API key is in play, so token consumption is real spend against that key.

`execute.py` does not merely record which of these applies after the fact — it **checks first and refuses to start** a cell that would land on `api` (including simple/bare mode, which never reads the subscription credential). This is a guard against silently drifting onto per-token billing, not a warning; there is no `--allow-api-billing` default and no environment variable that suppresses it. If the founder deliberately wants an API-billed comparison run, that flag must be passed to `execute.py` explicitly for that invocation (see step 3).

State plainly, for each approach:

- the number of measured sessions this approach will run (one session per cell in the pipeline)
- that three independent graders evaluate the result per cell
- the resulting total number of `claude` invocations, since that is what consumes rate-limit budget
- that a prior measured direct-Opus session on this machine reported approximately $0.16 API-equivalent for a trivial prompt, and that real story-sized prompts are significantly larger and consumption is genuinely unpredictable

**Any dollar figure you quote is an API-list-price equivalent for the tokens consumed — not a bill.** Say so explicitly. On a subscription it is a proxy for how much of the rate-limit window the run will use, nothing more. Present it as a range with its basis, and say plainly it is an estimate, not a guarantee. If the founder wants a firmer number, the pilot cell exists precisely to produce one.

Do not proceed without that confirmation.

## Steps

`<CELL>` below is `<APPROACH>` for an unversioned adapter and `<APPROACH>@<VERSION>` for a pinned one. Paths carry `<RUN_ID>` so repeats of the same cell do not overwrite each other.

For each approach, in the order given:

1. Resolve the ticket.

   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/resolve.py" \
     --key <TICKET> --repo <REPO> --out docs/benchmarks/<TICKET>/story.json
   ```

2. Provision a worktree. Pass `--version` when and only when the adapter declares one; `execute.py` refuses to run a cell whose identity disagrees with its adapter.

   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/provision.py" \
     --story docs/benchmarks/<TICKET>/story.json \
     --approach <APPROACH> --run-id <RUN_ID> --repo <REPO> \
     --adapter "${CLAUDE_PLUGIN_ROOT}/approaches/<APPROACH_FILE>.yaml" \
     [--version <VERSION>] \
     --out docs/benchmarks/<TICKET>/<CELL>/<RUN_ID>/cell.json
   ```

   `--adapter` is the same file passed to `execute.py` in step 3, and it is required here:
   provisioning writes the worktree's `enabledPlugins` from the adapter's declared plugin set.
   Without it the cell would inherit whatever plugins the operator has enabled, and a row labelled
   "no framework" would have run with every one of them loaded.

   Read provisioning's output. If it warns about hooks from user or repository settings, those run
   inside every measured session and cannot be disabled from the worktree — say so when reporting,
   because a hook that rewrites commands or injects text moves the number being measured.

   **On failure:** Abort this approach's cell, record the error, and continue to the next approach. Do not retry or skip to measure — the worktree is the evidence of what happened.

3. Execute.

   **Before it does anything else, `execute.py` runs a preflight billing guard.** If the environment would bill this run to an API key rather than the operator's subscription — an `ANTHROPIC_API_KEY`/`ANTHROPIC_AUTH_TOKEN` export, an `apiKeyHelper` in settings, or simple/bare mode (`CLAUDE_CODE_SIMPLE`, `--bare`), which never reads the subscription credential either — the run **aborts immediately**, before any setup hook and before `claude` is invoked. Nothing is spent. The error names exactly what was detected (variable or setting name only, never its value) and tells you to re-run with `--allow-api-billing` if that is genuinely what you want.

   Treat this as a real stop, not a retry-with-backoff situation: figure out why the machine looks API-billed (an exported key, a stray settings change) before proceeding. Only pass `--allow-api-billing` deliberately, per invocation, when an API-billed comparison run is the intended point of the sweep — it is not read from an environment variable, so it cannot be left on by accident. When passed, the run proceeds and `result.json`'s `billing_mode` still records `api`, so the report cannot misrepresent what actually happened.

   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/execute.py" \
     --cell docs/benchmarks/<TICKET>/<CELL>/<RUN_ID>/cell.json \
     --story docs/benchmarks/<TICKET>/story.json \
     --adapter "${CLAUDE_PLUGIN_ROOT}/approaches/<ADAPTER>.yaml" \
     --out docs/benchmarks/<TICKET>/<CELL>/<RUN_ID>/result.json
     # add --allow-api-billing only for a deliberate API-billed comparison run
   ```

   **On failure:** Abort this approach's cell, record the error, and continue to the next approach. Do not retry — this stage consumes real capacity. Never auto-retry without explicit founder confirmation. A preflight billing-guard abort is a failure of this kind — surface the error to the founder rather than adding the flag yourself.

   **On `PluginPinError`:** nothing was spent. Either the cell and its adapter disagree about which version this is (re-provision with matching `--approach`/`--version`), or the pinned version is no longer in the plugin cache. The error lists the versions still present — take that list to the founder rather than substituting a nearby version, which would silently change what the sweep answers.

   **If the output contains `ABNORMAL TERMINATION`:** the session was cut off mid-run — on a subscription, most often by the rate-limit window closing. The cell is FAILED. Still run **step 5 (measure)** so the record reaches `run.json` and the report can render the row as `CUT OFF`, then **skip step 6 (grade)** — grading a partial diff spends three more `claude` invocations to produce a number that means nothing. Do **not** sleep, retry, or resume. Report it to the founder, who re-runs the cell by hand once the cause has cleared.

4. Run tests inside the cell's worktree to capture test evidence for graders.

   Resolve the test command with the harness, never by reading the markdown cell yourself. The `Typecheck / Test` row is a **pair** — `<typecheck> / <test>` — where either side may be an em dash meaning "none". Interpolating the whole cell into a shell runs garbage, and `|| true` would turn that shell error into the "Test output" every grader reads.

   ```bash
   TEST_COMMAND=$(python3 -c "
   import sys; sys.path.insert(0, '${CLAUDE_PLUGIN_ROOT}/scripts')
   from pathlib import Path
   from benchlib import config
   cfg = config.load_config(Path('<REPO>'), {})
   print(config.require_command(cfg.test_command, 'test'))
   ")
   ```

   `require_command` exits non-zero with a clear message if no usable test command is configured. If it fails, **stop this cell and report it** — do not fall back to an empty command. Then run it with the worktree as the working directory, redirecting combined stdout and stderr to the cell's artifacts directory (read the `artifacts` path from the cell's cell.json):

   ```bash
   cd <WORKTREE> && eval "$TEST_COMMAND" > "<CELL_ARTIFACTS>/tests.txt" 2>&1 || true
   ```

   The destination is the cell's artifacts directory, which provision.py has already created at an absolute path outside the worktree — so test evidence survives worktree removal. The `|| true` ensures this step does not fail the cell even if tests fail — a failing test suite is exactly the evidence the grader needs. Continue regardless.

5. Measure. A non-zero exit means reconciliation failed, **or** the cell produced no code change, **or** the session did not terminate cleanly — report whichever it is, do not hide it.

   Read `run.json` after this step and surface four things to the founder if present:
   - `termination.clean: false` — **a failed cell.** The session was cut off mid-run and every figure it produced describes a partial run. **Skip grading for this cell** and let the report render it as `CUT OFF`. Do not sleep, retry, or resume; the founder re-runs it by hand.
   - `work_done.empty_diff: true` — **a failed cell.** The session committed nothing, so the graders would be grading an empty patch. Skip grading.
   - `reconciliation.unpriceable_models` — a model id with no rate card, so the computed cost is an undercount.
   - `phase_attribution.available: false` — the per-phase split is an artefact and the report will show `—`.
   - `plugin_version.ok: false` — **the pin did not take.** The session loaded a different version than the cell claims. The measurement is real but belongs to another version; the report relabels the row to what actually ran and marks it `WRONG VER`. Report it — a version comparison built on this row answers the wrong question.
   - `plugin_version.declared` set with `verified: false` — the pin could not be confirmed from the transcript because that plugin announces no root. Not a failure; say plainly that the version label rests on the declaration alone.

   The last two do not stop the cell; continue to grading and let the report render the row as failed.

   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/measure.py" \
     --cell docs/benchmarks/<TICKET>/<CELL>/<RUN_ID>/cell.json \
     --result docs/benchmarks/<TICKET>/<CELL>/<RUN_ID>/result.json \
     --adapter "${CLAUDE_PLUGIN_ROOT}/approaches/<ADAPTER>.yaml" \
     --out docs/benchmarks/<TICKET>/<CELL>/<RUN_ID>/run.json
   ```

6. Grade.

   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/grade.py" \
     --cell docs/benchmarks/<TICKET>/<CELL>/<RUN_ID>/cell.json \
     --story docs/benchmarks/<TICKET>/story.json \
     --out docs/benchmarks/<TICKET>/<CELL>/<RUN_ID>/grades.json
   ```

   **On failure:** Abort this approach's cell, record the error, and continue to the next approach. Do not retry — this stage spends grader invocations. Never auto-retry without explicit founder confirmation.

   **A non-zero exit with `FAILED CELL: nothing gradable`** means the cell's diff was non-empty but every changed path was stripped as a process artifact, leaving the graders an empty patch. No graders were invoked. `grades.json` records `filtered_diff_empty: true` and the stripped paths; the report renders the row as `NO PATCH` with its quality columns as `—` and its cost columns intact. Surface it to the founder — it usually means the ticket's deliverable lives entirely under a stripped path and is not a suitable benchmark subject.

Then render the report once, across every approach that ran:

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/report.py" \
  --ticket <TICKET> [--baseline <CELL>] --out docs/benchmarks/<TICKET>/report.md
```

Pass `--baseline` for a before/after sweep — e.g. `--baseline sdlc@0.44.0` — to get the deltas directly instead of leaving the founder to subtract rows by eye.

Report the table to the founder. Never merge a bench branch. Never delete a worktree that failed —
its transcript is the evidence.
