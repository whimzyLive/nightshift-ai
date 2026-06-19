---
description: >
  Per-pass logic for the Copilot review-and-fix cycle. Each invocation probes
  PR status, applies the decision table (wait / fix / stop), and returns — the
  native /loop command handles re-invocation and pacing. Exits cleanly only
  when Copilot has reviewed the current HEAD, all inline comments are resolved,
  and all required status checks pass. Halts and surfaces the failure if
  /review-fix errors or blocks. Does NOT merge the PR and does NOT process
  non-Copilot review comments.
---

# sdlc:loop — Copilot review-fix pass

**Note:** This command surfaces as `sdlc:loop` (plugin-namespaced) and is
distinct from the native `/loop`; it is designed as the per-pass body driven
BY native `/loop`, not a competing loop engine.

Drive **one pass** of the post-PR review-fix cycle for **`$ARGUMENTS`** (a
GitHub PR number or URL). The native `/loop` command handles iteration and
pacing (self-paced mode — it re-invokes this command after each pass and
terminates the loop when this pass does not schedule a next iteration). This
command NEVER merges the PR and ignores non-Copilot reviewers.

Repo slug: read `<owner>/<repo>` from `.claude/project/project-context.md`
(GitHub → Org/repo).

---

## Pass steps

### 1. Resolve the target PR (first pass only, or always as a guard)

```bash
gh pr view <PR> --json number,headRefName,baseRefName,url,state
```

If the PR is not OPEN → STOP the loop: surface "PR <PR> is not open — nothing
to loop on" and do NOT schedule a next iteration.

### 2. Ensure @copilot is a reviewer (AC-1)

Detect whether @copilot is already a requested reviewer by inspecting the
`reviewRequests` field returned by `gh pr view`. **Note:** `reviewRequests` may
not list the Copilot bot (GitHub does not reliably expose bot reviewers here),
so this detection is best-effort. When in doubt the loop treats the current HEAD
as not-yet-reviewed and waits or re-requests (rule 2 in the decision table).

If @copilot is not detected as a pending reviewer, add it best-effort:

```bash
gh pr edit <PR> --add-reviewer @copilot
```

Proceed without exiting regardless of outcome.

### 3. Probe current status (AC-2, AC-5)

```bash
dir=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/tmp-dir.sh)
bash ${CLAUDE_PLUGIN_ROOT}/scripts/pr-loop-status.sh <PR> "$dir/loop-copilot.json"
```

Read the `loop-status:` line — it contains six fields (in order):
`copilot-reviewed-head`, `copilot-pending`, `unresolved-copilot`,
`checks-pending`, `checks-failing`, `checks-passing`.

**Print progress to stdout (AC-5):** pass number, head oid (first 8 chars),
all six field values.

### 4. Apply the decision table

Evaluate the fields in the order below; the FIRST matching rule wins.

| # | Condition | Action |
|---|-----------|--------|
| 1 | `copilot-pending == 1` | Copilot is actively reviewing now (best-effort signal — see note). **WAIT** — schedule next iteration. No fix. |
| 2 | `copilot-reviewed-head == 0 && copilot-pending == 0` | Current HEAD has no Copilot review yet (initial wait, or post-push re-review needed). Re-request reviewer best-effort (`gh pr edit <PR> --add-reviewer @copilot`). **WAIT** — schedule next iteration. |
| 3 | `copilot-reviewed-head == 1 && unresolved-copilot > 0` | Real unresolved comments on current HEAD. Run `/review-fix <PR>` **INLINE** (in this session — do NOT dispatch a subagent; do NOT let review-fix run its own session-complete — this loop owns the single slot release). On success, schedule next iteration (the push moves HEAD, so next pass naturally re-enters rule 2 while Copilot re-reviews). On error or `Status: blocked` → **HALT** (see step 5). |
| 4 | `copilot-reviewed-head == 1 && unresolved-copilot == 0 && checks-failing == 0 && checks-pending == 0` | **GENUINE CLEAN** — STOP the loop (success). This is the ONLY valid clean exit. |
| 5 | `checks-pending > 0` (and rules 1–4 did not trigger) | CI still running. **WAIT** — schedule next iteration. |

> **`copilot-reviewed-head` is the load-bearing signal.** It is derived from
> the REST reviews API and is reliable. `copilot-pending` (derived from
> `reviewRequests`) is BEST-EFFORT: GitHub does not reliably expose bot
> reviewers in that field, so it may stay 0 even when the Copilot bot is
> mid-review. Rule 1 is therefore an optimisation only — it suppresses a
> redundant re-request when a review is confirmed in-flight. When
> `copilot-pending` is always 0, rule 2 fires instead and the loop still
> waits correctly (re-requesting and polling) until `copilot-reviewed-head`
> becomes 1. No exit path depends on `copilot-pending`.
>
> **Rule 4 is the only clean exit.** A zero `unresolved-copilot` while
> `copilot-reviewed-head == 0` means Copilot has NOT yet reviewed the current
> HEAD — that is rule 2 (wait), not a clean exit.

### 5. Halt on /review-fix failure (AC-4)

If the `/review-fix` run in rule 3 errors or returns `Status: blocked`, stop
the loop immediately. Print the failure details (which comment / what error) to
stdout and do NOT schedule a next iteration. Surface the error to the user.

### 6. Stall guard

If Copilot has not produced a review of the current HEAD after **15 minutes**
(approximately 15 self-paced passes at ~1 min each, or a configurable pass
counter), STOP the loop and surface:

> "Copilot did not review \<head-oid\> within 15 minutes. Stopping."

Track elapsed time or pass count from the first pass where
`copilot-reviewed-head == 0` for the current HEAD. Reset the counter whenever
HEAD advances (a new push happened). This prevents infinite waiting when the
Copilot reviewer is unavailable.

---

## Report

**On clean exit (rule 4):** print the final `loop-status:` line, total pass
count, total Copilot comments resolved across the run, and green-checks
confirmation.

**On halt (steps 5 or 6 / stall guard):** print the failing pass number and
the surfaced error or stall reason. Do not improvise around it.

---

## Final action — release the session (required)

After all pass logic above is complete (clean exit, halt, or stall-guard stop),
run this as your very last action:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh
```

It signals the automation worker to release this session's slot. Outside the
worker (`SDLC_SESSION_KEY` unset) it is a silent no-op — always safe to run.

---

GitHub PR number or URL:
$ARGUMENTS
