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

## In-session actions

`commands/loop.md` Step 3 now owns the probe + table for BOTH agents; this section carries
only the CI-b/CI-c action bodies its `review`/`fix` rows point at.

```text
DECISION=review (was CI-b) -> run REVIEW_CMD INLINE on this HEAD
  claude-inline      -> /code-review --comment <PR>
  claude-superpowers -> superpowers `requesting-code-review` skill; post findings inline
  FOUND := 1 iff review REPORTS >=1 finding (summary count, not "did a thread appear" —
           summary-only still records non-clean)
  [ "$CUR_HEAD" = - ] || printf '%s %s\n' "$CUR_HEAD" "$([ "$FOUND" = 1 ] && echo 0 || echo 1)" > "$REVIEW_MARK"
  loop-budget.sh check "$CUR_HEAD" "$CUR_UNRESOLVED" --progress # progress
  on-create -> STOP after this review+fix; on-update -> schedule next
DECISION=fix (was CI-c) -> /review-fix <PR> INLINE, identical to the Copilot path's fix action
RULE=CI-c2 (halt) -> print "<N> unresolved non-loop comment(s) on <HEAD> — review found
  nothing; leaving the PR open for a human." Do NOT run --on-clean.
```

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
