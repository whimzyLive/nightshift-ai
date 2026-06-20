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

Drive **one pass** of the post-PR review-fix cycle for the PR in **`$ARGUMENTS`**
(a GitHub PR number or URL, optionally followed by `--on-clean "<command>"`). The
native `/loop` command handles iteration and pacing (self-paced mode — it
re-invokes this command after each pass and terminates the loop when this pass
does not schedule a next iteration). This command NEVER merges the PR **itself**
and ignores non-Copilot reviewers.

**Arguments.** `$ARGUMENTS` is `<PR> [--on-clean "<command>"]`:

- `<PR>` — the PR number or URL to loop on.
- `--on-clean "<command>"` — OPTIONAL. A shell command run **once, only at the
  rule-4 clean exit** (head Copilot-reviewed, zero unresolved comments, checks
  green), immediately before the session release. It is **NOT** run on any halt
  (rules 5/6/7, `/review-fix` failure) or budget-exceeded path. This keeps
  `sdlc:loop` **mode-agnostic** — it never decides to merge; it only runs
  whatever terminal action the caller injected (e.g. `/auto` passes an auto-merge
  command for a Full Auto story; standalone `/spec`/`/plan`/`/impl` pass nothing).
  If `--on-clean` is absent, rule 4 simply stops.

**Parsing `$ARGUMENTS`.** Split it explicitly — do NOT pass the whole string to
`gh`:
- `PR` = the **first whitespace-delimited token** of `$ARGUMENTS`.
- If the literal `--on-clean` appears, everything after it (the quoted command)
  is the hook; capture it as `ON_CLEAN`. Otherwise `ON_CLEAN` is empty.

Use `PR` alone in every `gh pr ...` call (passing the whole `$ARGUMENTS` would
fail once `--on-clean` is present), and run `ON_CLEAN` only at the rule-4 clean
exit.

Repo slug: read `<owner>/<repo>` from `.claude/project/project-context.md`
(GitHub → Org/repo).

---

## Global loop budget

**Default: a 20-minute (1200-second) IDLE / no-progress timeout, also bounded
by an absolute 30-pass runaway backstop.** These defaults are configurable: the
budget values are set in the bash blocks below (the `BUDGET_SECS` and
`BUDGET_PASSES` variables) — adjust them before invoking if a different bound is
needed.

`BUDGET_SECS` bounds **inactivity**, not total runtime: the timer is reset to
"now" on every pass that makes progress (the reviewed head advanced, or the
unresolved-comment count changed). So a PR that keeps getting Copilot reviews
and fixes may run longer than 20 minutes as long as it keeps progressing; the
bound only ever fires when Copilot adds **nothing** for 20 minutes. This is a
ceiling on *waiting*, never a minimum runtime — a fast review-and-fix cycle
that reaches the clean exit (rule 4) ends immediately, regardless of elapsed
time. `BUDGET_PASSES` is a non-reset absolute ceiling that catches a
pathological fix↔re-review oscillation (too *much* activity) — the two bounds
are independent.

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
  # First pass: record the progress epoch (now), pass counter 0, and an empty progress
  # marker (head oid + unresolved count). Format: "<progress_epoch> <pass_count> <head> <unresolved>".
  progress_epoch=$(date +%s)
  printf '%s 0 - -\n' "$progress_epoch" > "$BUDGET_FILE"
fi
```

### Budget read and increment (every pass, before each WAIT)

Before scheduling any WAIT (rules 1, 2, or 5), read the budget file, increment
the pass counter, **reset the idle window if this pass made progress**, compute
idle elapsed seconds, and check both limits. This block runs AFTER the status
probe (step 3), so it has this pass's `CUR_HEAD` and `CUR_UNRESOLVED`:

```bash
dir=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/tmp-dir.sh)
BUDGET_FILE="$dir/loop-budget"
BUDGET_SECS=1200   # 20 minutes of NO PROGRESS (idle timeout — reset on progress, NOT total runtime)
BUDGET_PASSES=30   # absolute runaway backstop — NOT reset on progress

# CUR_HEAD / CUR_UNRESOLVED come from this pass's status probe (step 3):
#   CUR_HEAD       = the PR head oid (gh pr view --json headRefOid, or the probe's head field)
#   CUR_UNRESOLVED = the unresolved-copilot field from pr-loop-status.sh
# Default to placeholders if a field is somehow unavailable, so progress detection still runs.
CUR_HEAD="${CUR_HEAD:--}"
CUR_UNRESOLVED="${CUR_UNRESOLVED:--}"

read progress_epoch pass_count last_head last_unresolved < "$BUDGET_FILE"

# Validate fields: re-initialise empty/non-numeric numerics to avoid set -u crashes or a bogus
# huge elapsed (an empty file would coerce progress_epoch to 0 → elapsed ≈ 1.7e9 → trip on pass 1).
case "$progress_epoch" in (''|*[!0-9]*) progress_epoch=$(date +%s) ;; esac
case "$pass_count"     in (''|*[!0-9]*) pass_count=0 ;; esac
[ -n "$last_head" ] || last_head=-
[ -n "$last_unresolved" ] || last_unresolved=-

pass_count=$(( pass_count + 1 ))
now=$(date +%s)

# Reset the idle window on PROGRESS: a new reviewed head (Copilot reviewed a new oid, or a
# /review-fix push moved HEAD) or a changed unresolved-comment count since the last pass. Either
# means forward progress — the loop should keep going regardless of total elapsed time so far.
if [ "$CUR_HEAD" != "$last_head" ] || [ "$CUR_UNRESOLVED" != "$last_unresolved" ]; then
  progress_epoch=$now
fi

elapsed=$(( now - progress_epoch ))   # IDLE seconds: time since the last progress

# Clamp clock skew: if progress_epoch is in the future (NTP step-back), elapsed goes negative and
# the bound would be silently disabled (negative never satisfies -ge). Reset so the bound works.
if [ "$elapsed" -lt 0 ]; then
  elapsed=0
  progress_epoch=$now
fi

printf '%s %s %s %s\n' "$progress_epoch" "$pass_count" "$CUR_HEAD" "$CUR_UNRESOLVED" > "$BUDGET_FILE"

if [ "$elapsed" -ge "$BUDGET_SECS" ] || [ "$pass_count" -ge "$BUDGET_PASSES" ]; then
  # Budget exceeded — STOP.  BLOCKED_BY is set by the caller to describe which wait condition held
  # (see rules 1, 2, 5 below). The message reports idle seconds (no-progress), not total runtime.
  echo "Loop budget exceeded: ${elapsed}s idle (no progress) / ${pass_count} passes. Blocking condition: ${BLOCKED_BY}. Last status: $(cat "$dir/loop-status-last" 2>/dev/null || echo '(none)')"
  # Do NOT schedule a next iteration.
  exit 0   # <-- stop the loop
fi
```

The check runs BEFORE scheduling the WAIT, so the loop always stops promptly
when the idle bound (or the pass backstop) is hit. The budget is NOT checked on
rule 4 (clean exit) or on halt paths (rules 3 fail / step 5) — those have their
own exit logic, so a converged PR is never held open by the timer.

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

Read the `loop-status:` line — it contains seven fields (in order):
`copilot-reviewed-head`, `copilot-changes-requested`, `copilot-pending`,
`unresolved-copilot`, `checks-pending`, `checks-failing`, `checks-passing`.
`copilot-changes-requested=1` means Copilot's **latest review on the current
head is `CHANGES_REQUESTED`** — the PR is NOT clean even if `unresolved-copilot=0`
(e.g. a summary-only changes-requested review with no inline threads).

**Print progress to stdout (AC-5):** pass number, head oid (first 8 chars),
all seven field values.

**Persist the status line** for budget-exceeded messages:

```bash
# Replace <loop-status-line> with the actual line read from the script output
printf '%s\n' "<loop-status-line>" > "$dir/loop-status-last"
```

**Capture the progress signals for the idle budget.** The "Budget read and
increment" block (above) resets the idle window when the loop makes progress, so
it needs this pass's head oid and unresolved count:

```bash
CUR_HEAD=$(gh pr view <PR> --json headRefOid -q .headRefOid 2>/dev/null || echo -)
CUR_UNRESOLVED=<the unresolved-copilot field from the loop-status line>
```

Export both before running the budget block in any WAIT branch (rules 1, 2, 5).

### 4. Apply the decision table

Evaluate the fields in the order below; the FIRST matching rule wins.

| # | Condition | Action |
|---|-----------|--------|
| 1 | `copilot-pending == 1` | Copilot is actively reviewing now (best-effort signal — see note). **WAIT** — check budget first (set `BLOCKED_BY="copilot-review-pending (copilot-pending=1, head=<head-oid>)"`), then schedule next iteration. No fix. |
| 2 | `copilot-reviewed-head == 0 && copilot-pending == 0` | Current HEAD has no Copilot review yet (initial wait, or post-push re-review needed). Re-request reviewer best-effort (`gh pr edit <PR> --add-reviewer @copilot`). **WAIT** — check budget first (set `BLOCKED_BY="Copilot has not reviewed HEAD <head-oid>"`), then schedule next iteration. |
| 3 | `copilot-reviewed-head == 1 && (unresolved-copilot > 0 \|\| copilot-changes-requested == 1)` | Copilot has actionable feedback on current HEAD — either unresolved inline threads **or** a `CHANGES_REQUESTED` review (including a summary-only one with no inline threads). Run `/review-fix <PR>` **INLINE** (in this session — do NOT dispatch a subagent; do NOT let review-fix run its own session-complete — this loop owns the single slot release); `/review-fix` reads the review-summary body too, so a summary-only request is addressed. On success, schedule next iteration (the push moves HEAD, so next pass naturally re-enters rule 2 while Copilot re-reviews). On error or `Status: blocked` → **HALT** (see step 5). |
| 4 | `copilot-reviewed-head == 1 && copilot-changes-requested == 0 && unresolved-copilot == 0 && checks-failing == 0 && checks-pending == 0` | **GENUINE CLEAN** — Copilot's latest head review is NOT `CHANGES_REQUESTED`, no unresolved comments, checks green. If an `--on-clean "<command>"` was provided, run it **exactly once now** (this rule is the ONLY place it runs); if it exits non-zero, surface the error in the report (the PR is still raised — the caller decides whether that is terminal). Then STOP the loop (success). This is the ONLY valid clean exit. Budget is NOT checked here. |
| 5 | `checks-pending > 0` (and rules 1–4 did not trigger) | CI still running. **WAIT** — check budget first (set `BLOCKED_BY="checks still pending: P=<checks-pending value>"`), then schedule next iteration. |
| 6 | `copilot-reviewed-head == 1 && copilot-changes-requested == 0 && unresolved-copilot == 0 && checks-failing > 0 && checks-pending == 0` | **FAILING CHECKS — HALT.** Required check(s) are red and there are no unresolved Copilot comments left to fix. `/loop` cannot repair CI failures. Print: "Required check(s) failing (F=<checks-failing value>) on <head-oid> — /loop cannot fix CI; stopping." and do NOT schedule a next iteration. Budget is NOT checked here — this is an immediate terminal halt, same as AC-4. |
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

> Ordering with `--on-clean`: on a rule-4 clean exit the `--on-clean` command (if
> any) runs **before** this release — it is part of the terminal pass, not after
> the slot is freed. On halt/budget paths `--on-clean` does not run; this release
> still happens.

---

GitHub PR number or URL, optionally `--on-clean "<command>"`:
$ARGUMENTS
