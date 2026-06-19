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

## Global loop budget

**Default: 30 minutes wall-clock time (1800 seconds), also bounded by 30
passes.** These defaults are configurable: the budget values are set in the
bash blocks below (the `BUDGET_SECS` and `BUDGET_PASSES` variables) — adjust
them before invoking if a different bound is needed.

The budget covers ALL wait states — it is a single, unified bound regardless
of which wait rule (1, 2, or 5) is active. There is no separate Copilot-only
timer.

### Budget initialisation (first pass only)

On the very first pass, check whether the budget file exists. If it does not,
create it:

```bash
dir=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/tmp-dir.sh)
BUDGET_FILE="$dir/loop-budget"

if [ ! -f "$BUDGET_FILE" ]; then
  # First pass: record start epoch and initialise pass counter to 0
  start_epoch=$(date +%s)
  printf '%s 0\n' "$start_epoch" > "$BUDGET_FILE"
fi
```

### Budget read and increment (every pass, before each WAIT)

Before scheduling any WAIT (rules 1, 2, or 5), read the budget file,
increment the pass counter, compute elapsed seconds, and check both limits:

```bash
dir=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/tmp-dir.sh)
BUDGET_FILE="$dir/loop-budget"
BUDGET_SECS=1800   # 30 minutes
BUDGET_PASSES=30   # max pass count

read start_epoch pass_count < "$BUDGET_FILE"

# Validate fields: if either is empty or non-numeric, re-initialise to avoid
# arithmetic crashes under set -u or bogus elapsed values (e.g. empty file
# coerces start_epoch to 0, making elapsed ≈ 1.7e9 and tripping the budget
# immediately on pass 1).
case "$start_epoch" in
  (''|*[!0-9]*) start_epoch=$(date +%s); pass_count=0 ;;
esac
case "$pass_count" in
  (''|*[!0-9]*) pass_count=0 ;;
esac

pass_count=$(( pass_count + 1 ))
now=$(date +%s)
elapsed=$(( now - start_epoch ))

# Clamp clock skew: if start_epoch is in the future (e.g. NTP step-back),
# elapsed goes negative and the wall-clock bound is silently disabled because
# negative never satisfies -ge BUDGET_SECS.  Reset both so the bound works.
if [ "$elapsed" -lt 0 ]; then
  elapsed=0
  start_epoch=$now
fi

printf '%s %s\n' "$start_epoch" "$pass_count" > "$BUDGET_FILE"

if [ "$elapsed" -ge "$BUDGET_SECS" ] || [ "$pass_count" -ge "$BUDGET_PASSES" ]; then
  # Budget exceeded — STOP.  BLOCKED_BY is set by the caller to describe
  # which wait condition held (see rules 1, 2, 5 below).
  echo "Loop budget exceeded after ${elapsed}s / ${pass_count} passes. Blocking condition: ${BLOCKED_BY}. Last status: $(cat "$dir/loop-status-last" 2>/dev/null || echo '(none)')"
  # Do NOT schedule a next iteration.
  exit 0   # <-- stop the loop
fi
```

The check runs BEFORE scheduling the WAIT, so the loop always stops promptly
when the budget is hit. The budget is NOT checked on rule 4 (clean exit) or on
halt paths (rules 3 fail / step 5) — those have their own exit logic.

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

**Persist the status line** for budget-exceeded messages:

```bash
# Replace <loop-status-line> with the actual line read from the script output
printf '%s\n' "<loop-status-line>" > "$dir/loop-status-last"
```

### 4. Apply the decision table

Evaluate the fields in the order below; the FIRST matching rule wins.

| # | Condition | Action |
|---|-----------|--------|
| 1 | `copilot-pending == 1` | Copilot is actively reviewing now (best-effort signal — see note). **WAIT** — check budget first (set `BLOCKED_BY="copilot-review-pending (copilot-pending=1, head=<head-oid>)"`), then schedule next iteration. No fix. |
| 2 | `copilot-reviewed-head == 0 && copilot-pending == 0` | Current HEAD has no Copilot review yet (initial wait, or post-push re-review needed). Re-request reviewer best-effort (`gh pr edit <PR> --add-reviewer @copilot`). **WAIT** — check budget first (set `BLOCKED_BY="Copilot has not reviewed HEAD <head-oid>"`), then schedule next iteration. |
| 3 | `copilot-reviewed-head == 1 && unresolved-copilot > 0` | Real unresolved comments on current HEAD. Run `/review-fix <PR>` **INLINE** (in this session — do NOT dispatch a subagent; do NOT let review-fix run its own session-complete — this loop owns the single slot release). On success, schedule next iteration (the push moves HEAD, so next pass naturally re-enters rule 2 while Copilot re-reviews). On error or `Status: blocked` → **HALT** (see step 5). |
| 4 | `copilot-reviewed-head == 1 && unresolved-copilot == 0 && checks-failing == 0 && checks-pending == 0` | **GENUINE CLEAN** — STOP the loop (success). This is the ONLY valid clean exit. Budget is NOT checked here. |
| 5 | `checks-pending > 0` (and rules 1–4 did not trigger) | CI still running. **WAIT** — check budget first (set `BLOCKED_BY="checks still pending: P=<checks-pending value>"`), then schedule next iteration. |
| 6 | `copilot-reviewed-head == 1 && unresolved-copilot == 0 && checks-failing > 0 && checks-pending == 0` | **FAILING CHECKS — HALT.** Required check(s) are red and there are no unresolved Copilot comments left to fix. `/loop` cannot repair CI failures. Print: "Required check(s) failing (F=<checks-failing value>) on <head-oid> — /loop cannot fix CI; stopping." and do NOT schedule a next iteration. Budget is NOT checked here — this is an immediate terminal halt, same as AC-4. |
| 7 | _(catch-all — no rule above matched)_ | **UNEXPECTED STATE — HALT.** Print the current `loop-status:` line and "unexpected loop state — stopping to avoid a silent hang." Do NOT schedule a next iteration. No state may fall off the table silently. |

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
>
> **Budget applies to ALL WAIT paths (rules 1, 2, 5) only.** Rules 3, 4, 6,
> and 7 have their own exit paths and are never interrupted by the budget check.
>
> **Rule 6 ordering rationale.** Rule 6 (failing checks) is placed AFTER rule 3
> (unresolved comments). This means that when a PR has BOTH unresolved Copilot
> comments AND failing checks, rule 3 fires first and `/review-fix` runs — the
> code fix push may also resolve the CI failure. Only when `unresolved-copilot
> == 0` (nothing actionable left for `/review-fix`) does rule 6 halt on the
> failing checks. Placing rule 6 before rule 3 would prevent `/review-fix` from
> ever running when CI is red, which is the wrong behaviour.
>
> **Rule 7 (catch-all) is a safety net.** It must be the final rule. No
> combination of field values may fall off the table silently and terminate the
> loop without a surfaced reason.

#### Budget check detail for WAIT rules (1, 2, 5)

In each WAIT branch, before scheduling the next iteration:

1. Set the `BLOCKED_BY` variable to the condition-specific description (shown
   in the table above).
2. Run the **Budget read and increment** block from the "Global loop budget"
   section.
3. If the budget block exits (budget exceeded) → the loop stops with the
   message including `BLOCKED_BY` and the last status line.
4. If the budget block does NOT exit → schedule the next iteration normally.

### 5. Halt on /review-fix failure (AC-4)

If the `/review-fix` run in rule 3 errors or returns `Status: blocked`, stop
the loop immediately. Print the failure details (which comment / what error) to
stdout and do NOT schedule a next iteration. Surface the error to the user.
Budget is NOT checked here — this is an immediate halt.

---

## Report

**On clean exit (rule 4):** print the final `loop-status:` line, total pass
count, total Copilot comments resolved across the run, and green-checks
confirmation.

**On budget-exceeded stop (rules 1, 2, or 5):** print the elapsed time, pass
count, the blocking condition, and the last `loop-status:` line. Do not
improvise around it.

**On halt (step 5 / review-fix failure):** print the failing pass number and
the surfaced error or halt reason. Do not improvise around it.

**On failing-checks halt (rule 6):** print the failing pass number, the
`checks-failing` count, the head oid, and: "Required check(s) failing
(F=<n>) on <head-oid> — /loop cannot fix CI; stopping." Do not improvise
around it.

**On unexpected-state halt (rule 7):** print the current `loop-status:` line
and: "unexpected loop state — stopping to avoid a silent hang." Do not
improvise around it.

---

## Final action — release the session (required)

After all pass logic above is complete (clean exit, budget stop, or halt),
run this as your very last action:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh
```

It signals the automation worker to release this session's slot. Outside the
worker (`SDLC_SESSION_KEY` unset) it is a silent no-op — always safe to run.

---

GitHub PR number or URL:
$ARGUMENTS
