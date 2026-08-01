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

<!-- notation: `:=` define, `->` leads-to, `⊆` drawn-from-set, ASSERT/ELSE guard, first-match-wins ordering. Full legend: refs/pseudocode-notation.md -->

**Note:** This command surfaces as `sdlc:loop` (plugin-namespaced) and is
distinct from the native `/loop`; it is designed as the per-pass body driven
BY native `/loop`, not a competing loop engine.

Drive **one pass** of the post-PR review-fix cycle for the PR in **`$ARGUMENTS`**
(a GitHub PR number or URL, optionally followed by `--on-clean "<command>"`). The
native `/loop` command handles iteration and pacing (self-paced mode — it
re-invokes this command after each pass and terminates the loop when this pass
does not schedule a next iteration). This command NEVER merges the PR **itself**
and ignores non-Copilot reviewers.

**Arguments.** `$ARGUMENTS` is `<PR> [--phase <p>] [--on-clean "<command>"]`:

- `<PR>` — the PR number or URL to loop on.
- `--phase <p>` — OPTIONAL. A single phase-name token (`spec` | `plan` | `impl`)
  threaded through to the review-config reader (step 0) so the per-repo **Review
  gate** can downgrade this phase's effective `REVIEW_MODE` to `none`. The phase is
  passed literally per-invocation (NOT an env var) so it survives `/loop`
  re-invocation. Capture it as `PHASE` (empty when the flag is absent).
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
- If the literal `--phase` appears, the **single token after it** is the phase;
  capture it as `PHASE`. Otherwise `PHASE` is empty.
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
by an absolute 30-pass runaway backstop**, plus a SHORTER `REREVIEW_GRACE_SECS`
(default 600s) bound used only by rule 2b. Budget bookkeeping lives in
`scripts/loop-budget.sh` (D8 — the script owns only the budget; this file's own
decision table still decides WAIT vs fix vs exit). Two call sites:

```bash
# First pass only — idempotent, safe to call every pass.
bash ${CLAUDE_PLUGIN_ROOT}/scripts/loop-budget.sh init
```

```bash
# Before scheduling any WAIT (rules 1, 2a, 2b, 5) — pass --grace for rule 2b only.
bash ${CLAUDE_PLUGIN_ROOT}/scripts/loop-budget.sh check "$CUR_HEAD" "$CUR_UNRESOLVED" [--grace]
# exit 0 -> BUDGET_DECISION=CONTINUE, schedule the next iteration.
# exit 1 -> BUDGET_DECISION ⊆ {STOP_IDLE, STOP_PASSES}; stop the loop, printing
#           BUDGET_REASON, BLOCKED_BY (set per the matched WAIT row, below), and the
#           last `loop-status:` line. Do NOT schedule a next iteration.
```

`CUR_HEAD` / `CUR_UNRESOLVED` come from this pass's status probe (below); default
to `-` if a field is somehow unavailable, so progress detection still runs. The
budget covers ALL wait states — it is a single, unified bound regardless of which
WAIT rule is active, and is NOT checked on rule 4 (clean exit) or on halt paths
(rules 3 fail / step 5) — those have their own exit logic, so a converged PR is
never held open by the timer.

---

## Pass steps

### 0. Resolve the review agent + mode (every pass — cheap)

Who reviews **and** how the loop requests/waits for review is configured per-repo
in `.claude/project/project-context.md` → a `## Copilot Review` (or `## Code
Review`) section with two tokens. Read BOTH via the shared reader so the regex
and defaults live in one place:

```bash
# Pass the phase (when one was parsed) so the per-repo Review gate can downgrade
# this phase's effective REVIEW_MODE to `none`; otherwise use the plain no-flag call.
eval "$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/read-review-config.sh --phase "$PHASE")"   # when PHASE was parsed
# eval "$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/read-review-config.sh)"                  # when no --phase was given
# -> sets REVIEW_AGENT (github-copilot | claude-inline | claude-superpowers), REVIEW_MODE (none | on-create | on-update), REVIEW_GATE
```

When a **Review gate** is configured and the current `PHASE` is **not** in it, the
reader returns `REVIEW_MODE=none` — the existing `none` path below then runs
`--on-clean` exactly once and releases. The phase's review is skipped and the
pipeline advances; this is handled entirely by the existing `none` handling (no
new decision-table rule).

**`REVIEW_AGENT`** selects WHO reviews (default `github-copilot`; absent or
unrecognised ⇒ `github-copilot` + a WARNING on stderr — emitted by the reader):

- **`github-copilot`** — the GitHub Copilot bot is assigned as a PR reviewer and
  reviews **asynchronously**; the loop waits for it. This is the full behaviour
  the **GitHub Copilot path** below (this file's own probe + decision table)
  describes.
- **`claude-inline`** — there is no bot; the loop runs **`/code-review`
  in-session** to produce the review, then fixes via the same `/review-fix`
  machinery. Follow **Pass routing** below instead — it hands off to
  `refs/loop-modes.md`'s In-session review path for the rest of this pass.
- **`claude-superpowers`** — there is no bot; the loop runs the **superpowers
  `requesting-code-review` skill in-session** (a focused reviewer subagent over
  the PR diff) to produce the review, posts its findings as inline PR comments,
  then fixes via the same `/review-fix` machinery. Shares the same **Pass
  routing** hand-off as `claude-inline`; only the review command (`REVIEW_CMD`)
  differs, inside the ref.

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
  **Review-mode modifiers** note in `refs/loop-modes.md` for the full detail.)
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

### 2. Pass routing (every pass)

`REVIEW_AGENT` (from Step 0) selects the rest of this pass's body:

- `REVIEW_AGENT = github-copilot -> continue below` — the probe and decision
  table in this file are the entire GitHub Copilot path. `refs/loop-modes.md` is
  loaded ONLY when the matched decision-table row is an action row (2a, 2b, 3, 5,
  or 6) that needs Step 2/Step 5 detail or the row rationale — **never** for rule
  1 (pending-wait), rule 4 (clean exit), or rule 7 (catch-all halt), which are
  fully self-contained in the table below (D7).
- `REVIEW_AGENT ⊆ {claude-inline, claude-superpowers} -> read
  ${CLAUDE_PLUGIN_ROOT}/refs/loop-modes.md (explicit path) now` and follow its
  **In-session review path** section (CI-1 through CI-f) for the remainder of
  this pass — that section owns its own probe, decision table, and budget calls.
  ELSE (ref unreadable) → **STOP** with the missing path; never continue on a
  half-loaded contract.

## GitHub Copilot path (`REVIEW_AGENT=github-copilot`)

### 3. Decide (probe + apply the decision table)

Probe + decision table now live in `scripts/loop-decide.sh` (NA-93); golden pins all 1,458
cases against this file's PRE-change text. Call it, act on the answer — never improvise inline.

```text
decide := eval "$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/loop-decide.sh <PR> "$REVIEW_PATH" "$dir" "$REVIEW_MARK")"
       -> DECISION⊆{wait,fix,review,clean,halt}; RULE; REVIEW_PATH; HEAD; UNRESOLVED; FIELDS;
          GRACE; RE_REQUEST; BLOCKED_BY.  9 lines, <=600 B, exit 0 ALWAYS.
print (AC-5) := pass #, HEAD (8), RULE, FIELDS
persist       := printf '%s\n' "$FIELDS" > "$dir/loop-status-last"

DECISION=wait   -> loop-budget.sh check "$HEAD" "$UNRESOLVED" [--grace iff GRACE=yes]
                   RE_REQUEST=yes && on-update -> gh pr edit <PR> --add-reviewer @copilot
                   exit 0 -> schedule next; exit 1 -> STOP, print BUDGET_REASON + BLOCKED_BY
DECISION=fix    -> /review-fix <PR> INLINE (session model; loop owns slot release)
                   error/blocked -> HALT (Step 5, loop-modes.md)
                   on-create -> STOP after fix; on-update -> schedule next
DECISION=review -> REVIEW_CMD INLINE; write REVIEW_MARK; loop-budget.sh check; schedule next
                   (loop-modes.md `## In-session actions`)
DECISION=clean  -> ASSERT clean-guard ELSE treat as halt; run --on-clean once, then STOP
DECISION=halt   -> print RULE, FIELDS, BLOCKED_BY; do NOT schedule next
absent/outside enum/non-zero exit -> re-run ONCE; 2nd failure -> HALT, raw stdout printed.
                   NEVER infer a decision from prose or improvise the table here.

clean-guard := reviewed-head==1 && unresolved==0 && checks-failing==0 && checks-pending==0
               && (copilot: changes-requested==0 | in-session: review-clean==1)
parse each field OUT OF FIELDS -> never a substring match. guard fails, or a field
absent/non-numeric -> halt; print "clean guard rejected a clean decision on <HEAD> -
<FIELDS>"; STOP; never fall through to --on-clean.
```

---

## Report

**On clean exit (rule 4 / CI-d):** print the final `loop-status:` line, total pass
count, total review comments resolved across the run, and green-checks
confirmation.

**On budget-exceeded stop:** print `BUDGET_REASON` (from `loop-budget.sh check`),
`BLOCKED_BY`, the total pass count, and the last `loop-status:` line. Do not
improvise around it.

**On halt (Step 5 / review-fix failure):** print the failing pass number and
the surfaced error or halt reason. Do not improvise around it.

**On failing-checks halt (rule 6 / CI-e):** print the failing pass number, the
`checks-failing` count, the head oid, and: "Required check(s) failing
(F=<n>) on <head-oid> — /loop cannot fix CI; stopping." Do not improvise
around it.

**On unexpected-state halt (rule 7 / CI-f):** print the current `loop-status:`
line and: "unexpected loop state — stopping to avoid a silent hang." Do not
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

> Ordering with `--on-clean`: on a clean exit the `--on-clean` command (if
> any) runs **before** this release — it is part of the terminal pass, not after
> the slot is freed. On halt/budget paths `--on-clean` does not run; this release
> still happens.

---

GitHub PR number or URL, optionally `--on-clean "<command>"`:
$ARGUMENTS
