---
description: >
  Per-pass logic for the code review-and-fix cycle. Each invocation probes
  PR status, applies the decision table (wait / fix / stop), and returns — the
  native /loop command handles re-invocation and pacing. The reviewer is
  configurable per-repo (Review agent: github-copilot | claude-inline |
  claude-superpowers): Copilot reviews asynchronously as a PR reviewer,
  claude-inline runs /code-review in-session, claude-superpowers runs the
  superpowers requesting-code-review skill in-session. Exits cleanly only when
  the current HEAD has been reviewed, all
  inline comments are resolved, and all required status checks pass. Halts and
  surfaces the failure if /review-fix errors or blocks. Does NOT merge the PR.
---

# sdlc:loop — code review-fix pass

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
needed. A third, SHORTER bound — `REREVIEW_GRACE_SECS` (default 600s) — applies
only on rule 2b (Copilot reviewed an earlier head but isn't re-reviewing the
current one): a stalled re-review that may never arrive is bounded by this grace
instead of the full idle budget, so the loop stops promptly rather than spinning
for 20 minutes against a review that isn't coming.

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

Before scheduling any WAIT (rules 1, 2a, 2b, or 5), read the budget file, increment
the pass counter, **reset the idle window if this pass made progress**, compute
idle elapsed seconds, and check both limits. This block runs AFTER the status
probe (step 3), so it has this pass's `CUR_HEAD` and `CUR_UNRESOLVED`:

```bash
dir=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/tmp-dir.sh)
BUDGET_FILE="$dir/loop-budget"
BUDGET_SECS="${BUDGET_SECS:-1200}"   # 20 min of NO PROGRESS (idle timeout — reset on progress, NOT total runtime). Rule 2b lowers this to REREVIEW_GRACE_SECS BEFORE running this block.
REREVIEW_GRACE_SECS="${REREVIEW_GRACE_SECS:-600}"   # rule 2b: max wait for a STALLED re-review (Copilot reviewed an earlier head, not the current one) before stopping — much shorter than the full idle budget
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
  # (see rules 1, 2a, 2b, 5 below). The message reports idle seconds (no-progress), not total runtime.
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

### 0. Resolve the review agent + mode (every pass — cheap)

Who reviews **and** how the loop requests/waits for review is configured per-repo
in `.claude/project/project-context.md` → a `## Copilot Review` (or `## Code
Review`) section with two tokens. Read BOTH via the shared reader so the regex
and defaults live in one place:

```bash
eval "$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/read-review-config.sh)"
# -> sets REVIEW_AGENT (github-copilot | claude-inline | claude-superpowers) and REVIEW_MODE (none | on-create | on-update)
```

**`REVIEW_AGENT`** selects WHO reviews (default `github-copilot`; absent or
unrecognised ⇒ `github-copilot` + a WARNING on stderr — emitted by the reader):

- **`github-copilot`** — the GitHub Copilot bot is assigned as a PR reviewer and
  reviews **asynchronously**; the loop waits for it. This is the full behaviour
  the **GitHub Copilot path** (steps 1–5 below) and the decision table describe.
- **`claude-inline`** — there is no bot; the loop runs **`/code-review`
  in-session** to produce the review, then fixes via the same `/review-fix`
  machinery. Follow the **In-session review path** section (below the decision
  table) instead of steps 2–5; step 1 (resolve the PR) still applies, and the
  Global loop budget, `--on-clean` handling, and Final action are shared.
- **`claude-superpowers`** — there is no bot; the loop runs the **superpowers
  `requesting-code-review` skill in-session** (a focused reviewer subagent over
  the PR diff) to produce the review, posts its findings as inline PR comments,
  then fixes via the same `/review-fix` machinery. It shares the **In-session
  review path** with `claude-inline` — identical marker, decision table, budget,
  `--on-clean` handling, and Final action; only the review command (`REVIEW_CMD`)
  in CI-b differs. Chosen to cut per-review token cost vs the heavier native
  `/code-review` reasoning, while keeping review quality inside the plugin's own
  skill framework.

**`REVIEW_MODE`** selects the cadence (orthogonal to the agent):

- **`none`** — do NOT request a review and do NOT wait for one. Run the
  `--on-clean` command (if any) exactly once, then go straight to the **Final
  action — release the session**. The PR is still raised; `none` simply turns the
  review-fix loop into a no-op (no review gate). Skip every step below, for BOTH
  agents.
- **`on-create`** — review is requested/produced ONCE: for `github-copilot` the
  bot is requested at PR creation (by `raise-pr.sh`) and the loop does NOT
  re-request; for the in-session agents (`claude-inline`/`claude-superpowers`) the
  loop runs `REVIEW_CMD` once. Either way it runs `/review-fix` **at most once**
  (rule 3), then completes — it never waits for a re-review of the fix. (See the
  **Review-mode modifiers** note under the decision table.)
- **`on-update`** — review on every update: `github-copilot` re-requests each
  pass; the in-session agents (`claude-inline`/`claude-superpowers`) re-run
  `REVIEW_CMD` on each new HEAD. Keep fixing and re-reviewing until clean. This is
  the full behaviour the decision table below describes, and the default.

### 1. Resolve the target PR (first pass only, or always as a guard)

```bash
gh pr view <PR> --json number,headRefName,baseRefName,url,state
```

If the PR is not OPEN → STOP the loop: surface "PR <PR> is not open — nothing
to loop on" and do NOT schedule a next iteration.

## GitHub Copilot path (`REVIEW_AGENT=github-copilot`) — steps 2–5

> **Routing.** Steps 2–5 and the decision table are the **github-copilot** path:
> the bot reviews asynchronously and the loop waits for it. If
> `REVIEW_AGENT=claude-inline` **or `claude-superpowers`**, SKIP steps 2–5 and
> follow the **In-session review path** section (below the decision table) instead
> — it reuses step 1, the budget, `--on-clean`, and the Final action.

### 2. Ensure @copilot is a reviewer (AC-1)

Detect whether @copilot is already a requested reviewer by inspecting the
`reviewRequests` field returned by `gh pr view`. **Note:** `reviewRequests` may
not list the Copilot bot (GitHub does not reliably expose bot reviewers here),
so this detection is best-effort. When in doubt the loop treats the current HEAD
as not-yet-reviewed and waits or re-requests (rule 2a/2b in the decision table).

If @copilot is not detected as a pending reviewer, add it best-effort — **but only
in `on-update` mode**:

```bash
# Re-request only when the mode asks for per-update reviews. `on-create` relies on the
# single create-time request (raise-pr.sh) and must NOT re-request; `none` never reaches here.
[ "$REVIEW_MODE" = "on-update" ] && gh pr edit <PR> --add-reviewer @copilot
```

Proceed without exiting regardless of outcome.

### 3. Probe current status (AC-2, AC-5)

```bash
dir=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/tmp-dir.sh)
bash ${CLAUDE_PLUGIN_ROOT}/scripts/pr-loop-status.sh <PR> "$dir/loop-copilot.json"
```

Read the `loop-status:` line — it contains eight fields (in order):
`copilot-reviewed-head`, `copilot-changes-requested`, `copilot-pending`,
`unresolved-copilot`, `checks-pending`, `checks-failing`, `checks-passing`,
`copilot-reviewed-any`.
`copilot-changes-requested=1` means Copilot's **latest review on the current
head is `CHANGES_REQUESTED`** — the PR is NOT clean even if `unresolved-copilot=0`
(e.g. a summary-only changes-requested review with no inline threads).
`copilot-reviewed-any=1` means Copilot has reviewed **at least one** commit on this
PR (any head) — used by rules 2a/2b to tell an unstarted initial review (wait fully)
from a stalled re-review that may never arrive (short grace, then stop).

**Print progress to stdout (AC-5):** pass number, head oid (first 8 chars),
all eight field values.

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

Export both before running the budget block in any WAIT branch (rules 1, 2a, 2b, 5).

### 4. Apply the decision table

Evaluate the fields in the order below; the FIRST matching rule wins.

| # | Condition | Action |
|---|-----------|--------|
| 1 | `copilot-pending == 1` | Copilot is actively reviewing now (best-effort signal — see note). **WAIT** — check budget first (set `BLOCKED_BY="copilot-review-pending (copilot-pending=1, head=<head-oid>)"`), then schedule next iteration. No fix. |
| 2a | `copilot-reviewed-head == 0 && copilot-pending == 0 && copilot-reviewed-any == 0` | Copilot has not reviewed ANY head of this PR yet — the **initial** review has not started (and may not show as `pending` while it queues). Re-request reviewer best-effort (`gh pr edit <PR> --add-reviewer @copilot`). **WAIT with full patience** — leave `BUDGET_SECS` at its 1200s default, set `BLOCKED_BY="Copilot has not started the initial review of <head-oid>"`, check budget first, then schedule next iteration. |
| 2b | `copilot-reviewed-head == 0 && copilot-pending == 0 && copilot-reviewed-any == 1` | Copilot reviewed an **earlier** head but is NOT re-reviewing the current head and nothing is queued — a re-review **may never arrive** (e.g. the repo's Copilot review-on-push is limited/rate-limited). Re-request reviewer best-effort (`gh pr edit <PR> --add-reviewer @copilot`). **WAIT only a SHORT grace** — set `BUDGET_SECS="${REREVIEW_GRACE_SECS:-600}"` (the re-review grace, NOT the full idle budget) **before** running the budget block, set `BLOCKED_BY="Copilot has not queued a re-review of HEAD <head-oid> (it reviewed an earlier head) — review-on-push may be limited; merge/resolve manually or re-trigger"`, check budget first, then schedule next iteration. When the grace elapses with no re-review, the budget block STOPs the loop with that message instead of burning the full 20-minute idle budget. (If Copilot does pick the head up, the next pass sees `reviewed-head == 1` and moves to rule 3/4 before any budget check.) |
| 3 | `copilot-reviewed-head == 1 && (unresolved-copilot > 0 \|\| copilot-changes-requested == 1)` | Copilot has actionable feedback on current HEAD — either unresolved inline threads **or** a `CHANGES_REQUESTED` review (including a summary-only one with no inline threads). Run `/review-fix <PR>` **INLINE** (in this session — do NOT dispatch a subagent; do NOT let review-fix run its own session-complete — this loop owns the single slot release); `/review-fix` reads the review-summary body too, so a summary-only request is addressed. On success, schedule next iteration **in `on-update` mode** (the push moves HEAD, so next pass naturally re-enters rule 2a/2b while Copilot re-reviews); **in `on-create` mode STOP after this single fix** (do not schedule a next iteration — see Review-mode modifiers). On error or `Status: blocked` → **HALT** (see step 5). |
| 4 | `copilot-reviewed-head == 1 && copilot-changes-requested == 0 && unresolved-copilot == 0 && checks-failing == 0 && checks-pending == 0` | **GENUINE CLEAN** — Copilot's latest head review is NOT `CHANGES_REQUESTED`, no unresolved comments, checks green. If an `--on-clean "<command>"` was provided, run it **exactly once now** (this rule is the ONLY place it runs); if it exits non-zero, surface the error in the report (the PR is still raised — the caller decides whether that is terminal). Then STOP the loop (success). This is the ONLY valid clean exit. Budget is NOT checked here. |
| 5 | `checks-pending > 0` (and rules 1–4 did not trigger) | CI still running. **WAIT** — check budget first (set `BLOCKED_BY="checks still pending: P=<checks-pending value>"`), then schedule next iteration. |
| 6 | `copilot-reviewed-head == 1 && copilot-changes-requested == 0 && unresolved-copilot == 0 && checks-failing > 0 && checks-pending == 0` | **FAILING CHECKS — HALT.** Required check(s) are red and there are no unresolved Copilot comments left to fix. `/loop` cannot repair CI failures. Print: "Required check(s) failing (F=<checks-failing value>) on <head-oid> — /loop cannot fix CI; stopping." and do NOT schedule a next iteration. Budget is NOT checked here — this is an immediate terminal halt, same as AC-4. |
| 7 | _(catch-all — no rule above matched)_ | **UNEXPECTED STATE — HALT.** Print the current `loop-status:` line and "unexpected loop state — stopping to avoid a silent hang." Do NOT schedule a next iteration. No state may fall off the table silently. |

> **`copilot-reviewed-head` and `copilot-reviewed-any` are the load-bearing
> signals.** Both are derived from the REST reviews API and are reliable.
> `copilot-pending` (derived from `reviewRequests`) is BEST-EFFORT: GitHub does
> not reliably expose bot reviewers in that field, so it may stay 0 even when the
> Copilot bot is mid-review. Rule 1 is therefore an optimisation only — it
> suppresses a redundant re-request when a review is confirmed in-flight. When
> `copilot-pending` is always 0, the loop still behaves correctly via the
> `reviewed-head` / `reviewed-any` split:
> - `reviewed-any == 0` (rule 2a) — Copilot has not reviewed this PR at all yet;
>   the initial review is still pending, so the loop waits with FULL patience
>   (the 1200s idle budget) — a queueing first review may not surface as
>   `pending`, so we must not give up early.
> - `reviewed-any == 1 && reviewed-head == 0` (rule 2b) — Copilot already
>   reviewed an earlier head but is NOT re-reviewing the current one and nothing
>   is queued. This is the case where waiting the full budget is wrong: a
>   re-review may never come (the repo's Copilot review-on-push can be
>   limited/rate-limited). The loop re-requests once and waits only a SHORT grace
>   (`REREVIEW_GRACE_SECS`, default 600s), then STOPs with a clear message rather
>   than burning the full 20-minute idle budget on a review that isn't coming.
>
> This directly fixes the failure mode where Copilot reviewed a PR once (or a few
> times) and then stopped re-reviewing on later pushes, leaving the loop spinning
> against `reviewed-head == 0` until the full idle budget expired.
>
> **Rule 4 is the only clean exit.** A zero `unresolved-copilot` while
> `copilot-reviewed-head == 0` means Copilot has NOT yet reviewed the current
> HEAD — that is rule 2a/2b (wait), not a clean exit.
>
> **Budget applies to ALL WAIT paths (rules 1, 2a, 2b, 5) only.** Rules 3, 4, 6,
> and 7 have their own exit paths and are never interrupted by the budget check.
> Rule 2b uses the SAME budget block but with a shorter `BUDGET_SECS`
> (`REREVIEW_GRACE_SECS`), so its stop fires from the budget check too.
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
>
> **Review-mode modifiers (from step 0).** The table above is written for
> `on-update` (the default). The other modes adjust it:
> - **`none`** — handled in step 0; the loop never reaches this table (no review
>   request, no wait, immediate clean exit).
> - **`on-create`** — the rule-2a/2b reviewer **re-request is SKIPPED** (the
>   single create-time request from `raise-pr.sh` stands). Rule 2a still waits for
>   the one initial review. When **rule 3** fires, run `/review-fix` **once** and
>   then **STOP the loop** (do NOT schedule a next iteration): `on-create` caps the
>   cycle at a single fix and never waits for a re-review. After that one fix the
>   head moves, so a follow-up pass would see `reviewed-any == 1 && reviewed-head
>   == 0` — in `on-create` that is a **terminal STOP** ("on-create: one fix
>   applied; not waiting for a re-review"), NOT a rule-2b wait. Rule 4 (already
>   clean on the initial review) stops clean as usual.

#### Budget check detail for WAIT rules (1, 2a, 2b, 5)

In each WAIT branch, before scheduling the next iteration:

1. Set the `BLOCKED_BY` variable to the condition-specific description (shown
   in the table above).
2. **Rule 2b only:** set `BUDGET_SECS="${REREVIEW_GRACE_SECS:-600}"` before
   running the budget block, so the no-re-review wait is bounded by the short
   grace rather than the full 1200s idle budget. All other WAIT rules leave
   `BUDGET_SECS` at its 1200s default.
3. Run the **Budget read and increment** block from the "Global loop budget"
   section.
4. If the budget block exits (budget exceeded) → the loop stops with the
   message including `BLOCKED_BY` and the last status line.
5. If the budget block does NOT exit → schedule the next iteration normally.

### 5. Halt on /review-fix failure (AC-4)

If the `/review-fix` run in rule 3 errors or returns `Status: blocked`, stop
the loop immediately. Print the failure details (which comment / what error) to
stdout and do NOT schedule a next iteration. Surface the error to the user.
Budget is NOT checked here — this is an immediate halt.

---

## In-session review path (`REVIEW_AGENT=claude-inline` | `claude-superpowers`)

Entered from step 0 when `REVIEW_AGENT=claude-inline` **or `claude-superpowers`**.
Step 1 (resolve the PR) has already run; steps 2–5 and the github-copilot decision
table do NOT apply. There is **no async reviewer** — the loop performs the review
itself in-session (via `REVIEW_CMD`, below), then fixes via the **same**
`/review-fix` machinery (which is agent-agnostic: `pr-unresolved-comments.sh` /
`pr-resolve-comment.sh` do not filter by author), re-reviewing each new HEAD until
clean. This gives both in-session agents the **same** review → fix → re-review
cycle as Copilot (AC-4); only the **source** of the review comments differs
(AC-2/AC-3).

**The in-session reviewer — `REVIEW_CMD` — depends on `REVIEW_AGENT`:**

- **`claude-inline`** → run **`/code-review --comment <PR>`** (native in-session
  code review; no subagent). Unchanged from prior behaviour (AC-4).
- **`claude-superpowers`** → run the **superpowers `requesting-code-review`
  skill** instead: it dispatches a focused `code-reviewer` subagent over the PR
  diff (`origin/<base>...<head>`); post the findings it returns as **inline PR
  comments** on the current HEAD, so the shared `/review-fix` pipeline can action
  them exactly as for `claude-inline`. This keeps review reasoning inside the
  plugin's skill framework, lighter per review than native `/code-review`
  (AC-2/AC-3).

Everywhere below, **`REVIEW_CMD`** stands for whichever the configured agent
selects; the marker, decision table, budget, and modifiers are otherwise
**identical** for both agents. Where the steps below name `/code-review`
explicitly, read it as `REVIEW_CMD` — `claude-inline` keeps running
`/code-review --comment`, `claude-superpowers` runs the superpowers skill.

Because the loop runs the review synchronously, "has the current HEAD been
reviewed, and what did the review find?" is something the loop KNOWS rather than
probes from a bot. Track BOTH in a marker file — the reviewed head oid **and**
whether that review found anything (`clean=1` ⇒ `/code-review` reported zero
findings on that head). The clean flag is the **authoritative** "were there
findings?" signal: it comes straight from `/code-review`'s own report, so the
fix/clean decision never depends on GitHub's eventually-consistent inline-comment
indexing (a freshly-posted thread that the GraphQL read has not yet surfaced
cannot cause a premature clean exit).

### CI-1. Probe state (every pass)

```bash
dir=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/tmp-dir.sh)
REVIEW_MARK="$dir/loop-review-mark"        # format: "<reviewed-head-oid> <clean 0|1>"
read LAST_REVIEWED_HEAD LAST_REVIEW_CLEAN < "$REVIEW_MARK" 2>/dev/null || { LAST_REVIEWED_HEAD=-; LAST_REVIEW_CLEAN=-; }
[ -n "${LAST_REVIEWED_HEAD:-}" ] || LAST_REVIEWED_HEAD=-
# Validate the clean flag is exactly 0 or 1 (a half-written marker — CI-b's printf interrupted —
# would otherwise feed a partial token into the CI-2 tests and fall through to CI-f HALT). Any
# non-{0,1} value ⇒ treat this head as NOT cleanly reviewed: force a re-review via CI-b rather than
# guess. Pair it with a head reset so reviewed-head==0 holds.
case "$LAST_REVIEW_CLEAN" in 0|1) ;; *) LAST_REVIEW_CLEAN=-; LAST_REVIEWED_HEAD=- ;; esac
CUR_HEAD=$(gh pr view <PR> --json headRefOid -q .headRefOid 2>/dev/null || echo -)

# Unresolved inline review threads — the SAME agent-agnostic query the Copilot path's fixer uses.
# One NDJSON object per unresolved comment; count the lines. `grep -c` already PRINTS 0 on a
# no-match and exits 1; use `|| true` to swallow that exit — NOT `|| echo 0`, which would print a
# SECOND "0" and make CUR_UNRESOLVED the multi-line string "0\n0" that breaks every numeric test.
CUR_UNRESOLVED=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/pr-unresolved-comments.sh <PR> 2>/dev/null | grep -c . || true)
CUR_UNRESOLVED=${CUR_UNRESOLVED:-0}

# CI checks: reuse pr-loop-status.sh ONLY for its checks-* fields (its Copilot review
# fields are 0/irrelevant on this path and are ignored). Read checks-pending and checks-failing
# from the `loop-status:` line.
bash ${CLAUDE_PLUGIN_ROOT}/scripts/pr-loop-status.sh <PR> "$dir/loop-checks.json"
```

**Print progress to stdout:** pass number, head oid (first 8 chars),
`reviewed-head` (1 if `CUR_HEAD == LAST_REVIEWED_HEAD` else 0),
`review-clean=<LAST_REVIEW_CLEAN>`, `unresolved=<CUR_UNRESOLVED>`,
`checks-pending`, `checks-failing`.
Persist the printed status line to `$dir/loop-status-last` for budget messages.

### CI-2. Decision table (in-session review path)

Evaluate in order; the FIRST matching rule wins. `reviewed-head` below means
`CUR_HEAD == LAST_REVIEWED_HEAD` (the loop already ran `/code-review` on this oid).
`review-clean` is the marker's clean flag for that reviewed head.

| # | Condition | Action |
|---|-----------|--------|
| CI-a | `checks-pending > 0` | CI still running. **WAIT** — set `BLOCKED_BY="checks still pending: P=<checks-pending>"`, run the **Global loop budget** block, then schedule next iteration. |
| CI-b | `reviewed-head == 0` (`CUR_HEAD != LAST_REVIEWED_HEAD`) | Current HEAD not yet reviewed. Run **`REVIEW_CMD` INLINE** in this session — for `claude-inline`: `/code-review --comment <PR>` (no subagent); for `claude-superpowers`: the superpowers `requesting-code-review` skill (its `code-reviewer` subagent runs; post the findings it returns as inline PR comments on this HEAD). Either way the findings land as inline PR comments on this HEAD. Set `FOUND=1` if the review **reports ≥1 finding** (read its own summary/report count — NOT merely "did an inline thread appear", so a finding reported summary-only still records non-clean and cannot slip through as clean), else `0`. Record the marker — head **and** clean flag: `printf '%s %s\n' "$CUR_HEAD" "$([ "$FOUND" = 1 ] && echo 0 || echo 1)" > "$REVIEW_MARK"`. Run the budget block (pass-count backstop), then — because a review IS progress even when head/unresolved are unchanged — refresh the idle window so a long subsequent checks-pending wait isn't charged the review's time: `now=$(date +%s); read _pe pc h u < "$BUDGET_FILE"; printf '%s %s %s %s\n' "$now" "$pc" "$h" "$u" > "$BUDGET_FILE"`. Then schedule the next iteration. This is the review action — the synchronous analogue of waiting for Copilot. |
| CI-c | `reviewed-head == 1 && review-clean == 0` | The loop's OWN review (`/code-review`) reported findings on this HEAD (authoritative marker flag — NOT the raw unresolved count, so the loop never chases threads it didn't raise). Run **`/review-fix <PR>` INLINE** (identical to github-copilot rule 3 — fixes, resolves accepted threads; do NOT let `/review-fix` run its own session-complete — this loop owns the slot release). On success the fix pushes a new HEAD → next pass re-enters CI-b and re-reviews (**`on-update`**); in **`on-create`** STOP after this single fix (do not re-review — see modifiers). On error or `Status: blocked` → **HALT** (step 5). |
| CI-c2 | `reviewed-head == 1 && review-clean == 1 && unresolved > 0` | **NON-LOOP COMMENTS — STOP for a human.** The loop's review found nothing on this HEAD, yet unresolved inline threads remain — they were authored by someone other than the loop (a human reviewer, or threads `/review-fix` declined to resolve). The claude-inline loop does NOT process non-loop review comments (mirroring the github-copilot path, which counts only its reviewer's threads), and must NOT auto-merge over open human feedback. Print "<N> unresolved non-loop comment(s) on <head-oid> — review found nothing; leaving the PR open for a human." and do NOT schedule a next iteration (do NOT run `--on-clean`). This avoids burning the budget re-running `/review-fix` against comments it cannot resolve. |
| CI-d | `reviewed-head == 1 && review-clean == 1 && unresolved == 0 && checks-failing == 0 && checks-pending == 0` | **GENUINE CLEAN** — current HEAD reviewed, the review found nothing, no unresolved comments, checks green. If `--on-clean "<command>"` was provided, run it **exactly once now**; then **STOP** the loop (success). This is the ONLY valid clean exit. Budget is NOT checked here. |
| CI-e | `reviewed-head == 1 && review-clean == 1 && unresolved == 0 && checks-failing > 0` | **FAILING CHECKS — HALT.** Required check(s) are red and there is nothing left for `/review-fix` to do. Print "Required check(s) failing (F=<checks-failing>) on <head-oid> — /loop cannot fix CI; stopping." and do NOT schedule a next iteration. |
| CI-f | _(catch-all)_ | **UNEXPECTED STATE — HALT.** Print the status line and "unexpected loop state — stopping to avoid a silent hang." Do NOT schedule a next iteration. |

> **Budget.** The claude-inline path reuses the SAME **Global loop budget** block.
> Run it before scheduling any next iteration (CI-a wait, and after the CI-b
> review and CI-c fix), so both the idle timeout and the 30-pass runaway backstop
> apply uniformly. The progress signals are `CUR_HEAD`, `CUR_UNRESOLVED`, **and a
> CI-b review** (CI-b refreshes the budget file's idle epoch after running the
> budget block, since a synchronous review is real work even when it finds nothing
> and leaves head/unresolved unchanged).
> A HEAD that advanced (a fix) or a changed unresolved count also resets the idle
> window, so an actively-progressing review↔fix cycle runs as long as it
> progresses, while a stall (checks pending with no review happening) or an
> oscillation is bounded exactly as on the Copilot path. CI-d/CI-e/CI-f have their
> own terminal exits and are never interrupted by the budget.
>
> **`/code-review` is the in-session reviewer (AC-3).** It reviews the PR's diff
> and posts its findings as inline PR comments (`--comment`), which become the
> unresolved threads CI-c then fixes through the existing `/review-fix` pipeline
> — no Copilot bot, no reviewer assignment. The marker's `clean` flag (set from
> `/code-review`'s **reported finding count**, not from whether a thread has
> appeared) — NOT the eventually-consistent thread read — decides fix-vs-clean, so
> a just-posted comment that GraphQL has not yet indexed can never trigger a
> premature CI-d clean exit, and a finding reported summary-only still records
> `clean=0`. When `/code-review` reports nothing on a HEAD, `clean=1` is recorded
> and (checks permitting, no non-loop threads) the next pass reaches CI-d.
>
> **`unresolved` vs `clean` — two distinct signals.** `clean` (marker) answers
> "did the loop's own review find anything?" and drives the **fix** decision
> (CI-c). `unresolved` (raw thread count) answers "are there open threads from
> anyone?" and only gates the **exit**: CI-c2 stops for a human when non-loop
> threads remain, CI-d requires zero. The loop never runs `/review-fix` off the
> raw count, so it cannot churn against human comments it didn't raise (CI-c2
> stops instead).
>
> **Resolved `/code-review` contract.** `claude-inline` assumes the repo's
> in-session `/code-review` (a) reports a finding count this command can read for
> `FOUND`, and (b) posts those findings as **inline** review comments so
> `/review-fix` can action them. If the resolved `/code-review` reports findings
> but posts none inline, CI-c's `/review-fix` finds nothing to fix, the head does
> not move, and the loop stops on the no-progress budget bound — a non-merge
> (safe) outcome, never a false clean. A repo whose `/code-review` cannot post
> inline comments should use `Review agent = github-copilot` instead.
>
> **Review-mode modifiers (in-session review path).** (`REVIEW_CMD` = the
> configured agent's reviewer — `/code-review` for `claude-inline`, the superpowers
> `requesting-code-review` skill for `claude-superpowers`.)
> - **`none`** — handled in step 0; this path is never entered (no review, no
>   wait, immediate clean exit).
> - **`on-create`** — run `/code-review` once (CI-b) and `/review-fix` **once**
>   (CI-c), then **STOP** (do NOT re-review). After that single fix the head moves,
>   so a follow-up pass would see `reviewed-head == 0` — in `on-create` that is a
>   **terminal STOP** ("on-create: one review + fix applied; not re-reviewing"),
>   NOT another CI-b review.
> - **`on-update`** (default) — re-run `/code-review` on each new HEAD and keep
>   fixing until CI-d (clean), bounded by the budget.

---

## Report

**On clean exit (rule 4):** print the final `loop-status:` line, total pass
count, total Copilot comments resolved across the run, and green-checks
confirmation.

**On budget-exceeded stop (rules 1, 2a, 2b, or 5):** print the elapsed time, pass
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
