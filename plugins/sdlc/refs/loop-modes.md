# sdlc:loop — mode bodies

<!-- notation: `:=` define, `->` leads-to, `⊆` drawn-from-set, ASSERT/ELSE guard, first-match-wins ordering. Full legend: refs/pseudocode-notation.md -->

Loaded from `commands/loop.md`'s **Pass routing** step. **Never loaded on a WAIT or clean-exit pass**
(D7) — the fast path's own decision table is fully self-contained for those outcomes. This file
holds two things: (1) additional detail for the **GitHub Copilot path**'s action rows (re-requesting
a reviewer, the halt path, and the rationale behind the table's row ordering) — read only when the
fast path's decision table matched an action row (fix, re-request, halt); (2) the **entire
in-session review path** (`REVIEW_AGENT=claude-inline` or `claude-superpowers`) — read on every pass
for that configuration, since there is no async bot and the loop's own probe + decision are
themselves the mode-specific body.

---

## GitHub Copilot path — additional detail (Step 2, Step 5, and the row rationale)

> Read this section only after the fast path's decision table (in `commands/loop.md`) has matched
> rule 2a, 2b, 3, 5, or 6 — i.e. the pass needs to re-request a reviewer, run `/review-fix`, or halt.
> Rules 1, 4, and 7 (pending-wait, clean exit, catch-all) never need this detail.

### Step 2 — Ensure @copilot is a reviewer (AC-1)

Detect whether @copilot is already a requested reviewer by inspecting the `reviewRequests` field
returned by `gh pr view`. **Note:** `reviewRequests` may not list the Copilot bot (GitHub does not
reliably expose bot reviewers here), so this detection is best-effort. When in doubt the loop treats
the current HEAD as not-yet-reviewed and waits or re-requests (rule 2a/2b in the fast path's decision
table).

If @copilot is not detected as a pending reviewer, add it best-effort — **but only in `on-update`
mode** (the fast path's rule 2a/2b action cells already give the exact command):

```bash
# Re-request only when the mode asks for per-update reviews. `on-create` relies on the
# single create-time request (raise-pr.sh) and must NOT re-request; `none` never reaches here.
[ "$REVIEW_MODE" = "on-update" ] && gh pr edit <PR> --add-reviewer @copilot
```

Proceed without exiting regardless of outcome.

### Step 5 — Halt on /review-fix failure (AC-4)

If the `/review-fix` run (fast-path rule 3) errors or returns `Status: blocked`, stop the loop
immediately. Print the failure details (which comment / what error) to stdout and do NOT schedule a
next iteration. Surface the error to the user. Budget is NOT checked here — this is an immediate
halt.

### Row rationale (why the fast-path decision table is ordered and worded this way)

> **`copilot-reviewed-head` and `copilot-reviewed-any` are the load-bearing signals.** Both are
> derived from the REST reviews API and are reliable. `copilot-pending` (derived from
> `reviewRequests`) is BEST-EFFORT: GitHub does not reliably expose bot reviewers in that field, so
> it may stay 0 even when the Copilot bot is mid-review. Rule 1 is therefore an optimisation only —
> it suppresses a redundant re-request when a review is confirmed in-flight. When `copilot-pending`
> is always 0, the loop still behaves correctly via the `reviewed-head` / `reviewed-any` split:
>
> - `reviewed-any == 0` (rule 2a) — Copilot has not reviewed this PR at all yet; the initial review
>   is still pending, so the loop waits with FULL patience (the 1200s idle budget) — a queueing
>   first review may not surface as `pending`, so we must not give up early.
> - `reviewed-any == 1 && reviewed-head == 0` (rule 2b) — Copilot already reviewed an earlier head
>   but is NOT re-reviewing the current one and nothing is queued. This is the case where waiting the
>   full budget is wrong: a re-review may never come (the repo's Copilot review-on-push can be
>   limited/rate-limited). The loop re-requests once and waits only a SHORT grace
>   (`REREVIEW_GRACE_SECS`, default 600s — `loop-budget.sh check ... --grace`), then STOPs with a
>   clear message rather than burning the full 20-minute idle budget on a review that isn't coming.
>
> This directly fixes the failure mode where Copilot reviewed a PR once (or a few times) and then
> stopped re-reviewing on later pushes, leaving the loop spinning against `reviewed-head == 0` until
> the full idle budget expired.
>
> **Rule 4 is the only clean exit.** A zero `unresolved-copilot` while `copilot-reviewed-head == 0`
> means Copilot has NOT yet reviewed the current HEAD — that is rule 2a/2b (wait), not a clean exit.
>
> **Rule 6 ordering rationale.** Rule 6 (failing checks) is placed AFTER rule 3 (unresolved
> comments). When a PR has BOTH unresolved Copilot comments AND failing checks, rule 3 fires first
> and `/review-fix` runs — the code fix push may also resolve the CI failure. Only when
> `unresolved-copilot == 0` (nothing actionable left for `/review-fix`) does rule 6 halt on the
> failing checks. Placing rule 6 before rule 3 would prevent `/review-fix` from ever running when CI
> is red, which is the wrong behaviour.
>
> **Rule 7 (catch-all) is a safety net.** It must be the final rule. No combination of field values
> may fall off the table silently and terminate the loop without a surfaced reason.
>
> **Review-mode modifiers (from Step 0).** The table is written for `on-update` (the default). The
> other modes adjust it:
>
> - **`none`** — handled in Step 0; the loop never reaches the table (no review request, no wait,
>   immediate clean exit).
> - **`on-create`** — the rule-2a/2b reviewer **re-request is SKIPPED** (the single create-time
>   request from `raise-pr.sh` stands). Rule 2a still waits for the one initial review. When **rule
>   3** fires, run `/review-fix` **once** and then **STOP the loop** (do NOT schedule a next
>   iteration): `on-create` caps the cycle at a single fix and never waits for a re-review. After
>   that one fix the head moves, so a follow-up pass would see `reviewed-any == 1 && reviewed-head ==
>   0` — in `on-create` that is a **terminal STOP** ("on-create: one fix applied; not waiting for a
>   re-review"), NOT a rule-2b wait. Rule 4 (already clean on the initial review) stops clean as
>   usual.

---

## In-session review path (`REVIEW_AGENT=claude-inline` | `claude-superpowers`)

Entered from `commands/loop.md`'s **Pass routing** step when `REVIEW_AGENT=claude-inline` **or
`claude-superpowers`**. `commands/loop.md`'s Step 1 (resolve the PR) has already run; the GitHub
Copilot path's probe and decision table do NOT apply. There is **no async reviewer** — the loop
performs the review itself in-session (via `REVIEW_CMD`, below), then fixes via the **same**
`/review-fix` machinery (agent-agnostic: `pr-unresolved-comments.sh` / `pr-resolve-comment.sh` do
not filter by author), re-reviewing each new HEAD until clean. This gives both in-session agents the
**same** review → fix → re-review cycle as Copilot (AC-4); only the **source** of the review
comments differs (AC-2/AC-3).

**The in-session reviewer — `REVIEW_CMD` — depends on `REVIEW_AGENT`:**

- **`claude-inline`** → run **`/code-review --comment <PR>`** (native in-session code review; no
  subagent). Unchanged from prior behaviour (AC-4).
- **`claude-superpowers`** → run the **superpowers `requesting-code-review` skill** instead: it
  dispatches a focused `code-reviewer` subagent over the PR diff (`origin/<base>...<head>`); post the
  findings it returns as **inline PR comments** on the current HEAD, so the shared `/review-fix`
  pipeline can action them exactly as for `claude-inline`. This keeps review reasoning inside the
  plugin's skill framework, lighter per review than native `/code-review` (AC-2/AC-3).

Everywhere below, **`REVIEW_CMD`** stands for whichever the configured agent selects; the marker,
decision table, budget, and modifiers are otherwise **identical** for both agents. Where the steps
below name `/code-review` explicitly, read it as `REVIEW_CMD` — `claude-inline` keeps running
`/code-review --comment`, `claude-superpowers` runs the superpowers skill.

Because the loop runs the review synchronously, "has the current HEAD been reviewed, and what did
the review find?" is something the loop KNOWS rather than probes from a bot. Track BOTH in a marker
file — the reviewed head oid **and** whether that review found anything (`clean=1` ⇒ `/code-review`
reported zero findings on that head). The clean flag is the **authoritative** "were there findings?"
signal: it comes straight from `/code-review`'s own report, so the fix/clean decision never depends
on GitHub's eventually-consistent inline-comment indexing (a freshly-posted thread that the GraphQL
read has not yet surfaced cannot cause a premature clean exit).

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
| --- | --- | --- |
| CI-a | `checks-pending > 0` | CI still running. **WAIT** — set `BLOCKED_BY="checks still pending: P=<checks-pending>"`, run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/loop-budget.sh check <head> <unresolved>` (STOP on exit 1, else schedule next iteration). |
| CI-b | `reviewed-head == 0` (`CUR_HEAD != LAST_REVIEWED_HEAD`) | Current HEAD not yet reviewed. Run **`REVIEW_CMD` INLINE** in this session — for `claude-inline`: `/code-review --comment <PR>` (no subagent); for `claude-superpowers`: the superpowers `requesting-code-review` skill (its `code-reviewer` subagent runs; post the findings it returns as inline PR comments on this HEAD). Either way the findings land as inline PR comments on this HEAD. Set `FOUND=1` if the review **reports ≥1 finding** (read its own summary/report count — NOT merely "did an inline thread appear", so a finding reported summary-only still records non-clean and cannot slip through as clean), else `0`. Record the marker — head **and** clean flag: `printf '%s %s\n' "$CUR_HEAD" "$([ "$FOUND" = 1 ] && echo 0 \|\| echo 1)" > "$REVIEW_MARK"`. Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/loop-budget.sh check "$CUR_HEAD" "$CUR_UNRESOLVED"` (pass-count backstop) — a review IS progress even when head/unresolved are unchanged, so pass `$CUR_HEAD`/`$CUR_UNRESOLVED` unchanged and let the script's own pass-count increment cover it; if the check returns CONTINUE, schedule the next iteration. This is the review action — the synchronous analogue of waiting for Copilot. |
| CI-c | `reviewed-head == 1 && review-clean == 0` | The loop's OWN review (`/code-review`) reported findings on this HEAD (authoritative marker flag — NOT the raw unresolved count, so the loop never chases threads it didn't raise). Run **`/review-fix <PR>` INLINE** (identical to github-copilot rule 3 — fixes, resolves accepted threads; do NOT let `/review-fix` run its own session-complete — this loop owns the slot release). On success the fix pushes a new HEAD → next pass re-enters CI-b and re-reviews (**`on-update`**); in **`on-create`** STOP after this single fix (do not re-review — see modifiers). On error or `Status: blocked` → **HALT** (Step 5, GitHub Copilot path section above — the halt text is agent-agnostic). |
| CI-c2 | `reviewed-head == 1 && review-clean == 1 && unresolved > 0` | **NON-LOOP COMMENTS — STOP for a human.** The loop's review found nothing on this HEAD, yet unresolved inline threads remain — they were authored by someone other than the loop (a human reviewer, or threads `/review-fix` declined to resolve). The claude-inline loop does NOT process non-loop review comments (mirroring the github-copilot path, which counts only its reviewer's threads), and must NOT auto-merge over open human feedback. Print "<N> unresolved non-loop comment(s) on <head-oid> — review found nothing; leaving the PR open for a human." and do NOT schedule a next iteration (do NOT run `--on-clean`). This avoids burning the budget re-running `/review-fix` against comments it cannot resolve. |
| CI-d | `reviewed-head == 1 && review-clean == 1 && unresolved == 0 && checks-failing == 0 && checks-pending == 0` | **GENUINE CLEAN** — current HEAD reviewed, the review found nothing, no unresolved comments, checks green. If `--on-clean "<command>"` was provided, run it **exactly once now**; then **STOP** the loop (success). This is the ONLY valid clean exit. Budget is NOT checked here. |
| CI-e | `reviewed-head == 1 && review-clean == 1 && unresolved == 0 && checks-failing > 0` | **FAILING CHECKS — HALT.** Required check(s) are red and there is nothing left for `/review-fix` to do. Print "Required check(s) failing (F=<checks-failing>) on <head-oid> — /loop cannot fix CI; stopping." and do NOT schedule a next iteration. |
| CI-f | _(catch-all)_ | **UNEXPECTED STATE — HALT.** Print the status line and "unexpected loop state — stopping to avoid a silent hang." Do NOT schedule a next iteration. |

> **Budget.** The claude-inline path reuses the SAME `loop-budget.sh` script. Run it before
> scheduling any next iteration (CI-a wait, and after the CI-b review and CI-c fix), so both the
> idle timeout and the 30-pass runaway backstop apply uniformly. The progress signals are
> `CUR_HEAD`, `CUR_UNRESOLVED`, **and a CI-b review** (a synchronous review is real work even when it
> finds nothing and leaves head/unresolved unchanged — the pass-count still advances via the
> script's own increment, so a stuck-but-reviewing loop still hits the 30-pass backstop eventually).
> A HEAD that advanced (a fix) or a changed unresolved count also resets the idle window via the
> script's own progress detection, so an actively-progressing review↔fix cycle runs as long as it
> progresses, while a stall (checks pending with no review happening) or an oscillation is bounded
> exactly as on the Copilot path. CI-d/CI-e/CI-f have their own terminal exits and are never
> interrupted by the budget.
>
> **`/code-review` is the in-session reviewer (AC-3).** It reviews the PR's diff and posts its
> findings as inline PR comments (`--comment`), which become the unresolved threads CI-c then fixes
> through the existing `/review-fix` pipeline — no Copilot bot, no reviewer assignment. The marker's
> `clean` flag (set from `/code-review`'s **reported finding count**, not from whether a thread has
> appeared) — NOT the eventually-consistent thread read — decides fix-vs-clean, so a just-posted
> comment that GraphQL has not yet indexed can never trigger a premature CI-d clean exit, and a
> finding reported summary-only still records `clean=0`. When `/code-review` reports nothing on a
> HEAD, `clean=1` is recorded and (checks permitting, no non-loop threads) the next pass reaches
> CI-d.
>
> **`unresolved` vs `clean` — two distinct signals.** `clean` (marker) answers "did the loop's own
> review find anything?" and drives the **fix** decision (CI-c). `unresolved` (raw thread count)
> answers "are there open threads from anyone?" and only gates the **exit**: CI-c2 stops for a human
> when non-loop threads remain, CI-d requires zero. The loop never runs `/review-fix` off the raw
> count, so it cannot churn against human comments it didn't raise (CI-c2 stops instead).
>
> **Resolved `/code-review` contract.** `claude-inline` assumes the repo's in-session `/code-review`
> (a) reports a finding count this command can read for `FOUND`, and (b) posts those findings as
> **inline** review comments so `/review-fix` can action them. If the resolved `/code-review` reports
> findings but posts none inline, CI-c's `/review-fix` finds nothing to fix, the head does not move,
> and the loop stops on the no-progress budget bound — a non-merge (safe) outcome, never a false
> clean. A repo whose `/code-review` cannot post inline comments should use `Review agent =
> github-copilot` instead.
>
> **Review-mode modifiers (in-session review path).** (`REVIEW_CMD` = the configured agent's
> reviewer — `/code-review` for `claude-inline`, the superpowers `requesting-code-review` skill for
> `claude-superpowers`.)
>
> - **`none`** — handled in Step 0; this path is never entered (no review, no wait, immediate clean
>   exit).
> - **`on-create`** — run `/code-review` once (CI-b) and `/review-fix` **once** (CI-c), then **STOP**
>   (do NOT re-review). After that single fix the head moves, so a follow-up pass would see
>   `reviewed-head == 0` — in `on-create` that is a **terminal STOP** ("on-create: one review + fix
>   applied; not re-reviewing"), NOT another CI-b review.
> - **`on-update`** (default) — re-run `/code-review` on each new HEAD and keep fixing until CI-d
>   (clean), bounded by the budget.
