# NA-93 pilot obligation

NA-93's own implementation run is **not** the pilot, for two independent reasons, same shape as
NA-87/88/90/91/92: H changes the loop pass's own contract, so this run executed the PRE-change
contract throughout; and `plugins/**` edits do not reach running agents at all — they read
`CLAUDE_PLUGIN_ROOT` (the cache), not the repo. An after-number from this run would measure the old
contract while reading as if it measured the new one. The live-input run this story ships
(`live-input-evidence.txt`'s four real-PR `loop-decide.sh` invocations, plus the real-corpus
`--replay` run) exercised the script against real GitHub state and a real session corpus, but that
proves the script is not inert (at least one live invocation resolves to a non-`unresolvable` rule)
and that the table it ships matches a pre-change golden — it does not prove any session actually
routes a live loop pass through the script instead of the pre-change inline table, because no
running session reads `plugins/**` from this repo.

Pilot selection rule — the first Jira story satisfying ALL of, in this order, no discretion:

```text
pilot := the FIRST Jira story satisfying ALL of:
  (a) TRIAGE=full                            # story points > 3, the project-context threshold
  (b) run end-to-end through /sdlc:auto      # the loop must run on a spec, plan AND impl PR
  (c) started AFTER: NA-93 merged to develop
                     AND `pnpm nx release version -p sdlc` has run
                     AND the CLAUDE_PLUGIN_ROOT cache is updated to that released version
                     AND .claude/.sdlc-plugin-root points at it
  (d) NOT authored by NA-93 and NOT another NA-76 child   # the programme must not measure itself
  (e) its loop reaches DECISION=clean at least once       # else the clean guard is unexercised
relaxation := if the first THREE stories satisfying (a)-(d) all fail (e), take the third and mark
              the clean-guard row NOT CAPTURED
record the chosen key verbatim in the merged PR body
```

The pilot MUST report, at minimum, using the same table shape as `measurement-block.txt`, with
every row filled or explicitly marked `NOT CAPTURED — <reason>`.

Binding pass conditions — **five, not fourteen** (amendment A12; the pilot's own report still
carries all fourteen rows, but only five are decidable at n=1 with no matched control):

```text
ASSERT loop-decide.sh ran exactly once per pass, and no loop-pass turn re-derived the table
ASSERT returnCapExceeded == false
ASSERT clean-guard rejections == 0
ASSERT cacheReadRatio >= 0.94                # absolute threshold, decidable at n=1
ASSERT every RULE=unresolvable occurrence is recorded with its BLOCKED_BY
ELSE revert per H4 — never trade a guardrail for instruction surface

RECORD, never ASSERT: loop passes per PR, resident @ loop-pass turns, billed session-model tokens,
   requests per story, QA rounds, blocked rate, review findings
   # every one is a distributional claim with no matched control; at n=1 a value inside the
   # 45-session spread is absence of a visible regression, NOT evidence of improvement
```

**What n = 1 can and cannot decide, stated so a future reader cannot mistake a passing pilot for
proof of a cut.** The five ASSERT rows above are **binary** — one story decides them outright,
because each is a property of a single observed run (an invocation count, a byte cap, a guard
rejection count, an absolute ratio threshold, a recorded-with-reason check), not a distributional
claim. Every "not increased" row in the RECORD set — loop passes per PR, resident tokens (mean and
Σ), billed session-model tokens, requests per story, QA rounds, blocked rate, review findings — is
**distributional** with no matched control. A pilot landing inside the spread of the 45-session
baseline (loop-pass turns: 262 across 45 sessions, fable-5 129 / opus-4-8 98 / opus-5 35;
top-level resident mean 254,390, Σ 66,650,150; cacheReadRatio 0.9660) is **absence of a visible
regression**, not evidence of improvement. A pilot report marking these rows PASS instead of
UNDECIDABLE has over-claimed, regardless of what the numbers say.

Failure of any of the five binding ASSERTs -> **revert per H4 — never trade the guardrail for
instruction surface** (AC-2, verbatim). AC-5's 3.0% figure — and this story's own **1.52% of
top-level resident tokens removed from every model tier**, **-9,991 B of per-pass top-level
instruction surface**, and **1,458-case exhaustive decision equivalence** claim — stays
**uncounted** toward the programme's stretch AC-1 until the pilot passes every one of the five
gates. Record the pilot's chosen key in the merged PR body (AC-4) and comment it on NA-93, so the
obligation cannot be silently dropped.

**The revert lever, verbatim (H4):** `git revert <H-sha>` then `pnpm nx release version -p sdlc` +
cache update. H's diff touches `commands/loop.md`, `refs/loop-modes.md`, `scripts/loop-decide.sh`,
`scripts/__tests__/`, `tools/sdlc-analyser/`, `.github/workflows/ci.yml`, `docs/adr/` — no hunk
shared with workstreams E, F or G, so the revert applies cleanly over any of them.

**NOT CAPTURED register — no row here may be estimated or back-filled.** Loop-pass turns after,
invocations per pass, `returnCapExceeded` after, clean-guard rejections after, `RULE=unresolvable`
occurrences after, `cacheReadRatio` after. Reason, both independent: H changes the loop pass's own
contract, so NA-93's own shipping run executed the PRE-change contract; and `plugins/**` edits do
not reach running agents, which read `CLAUDE_PLUGIN_ROOT` (the cache), not the repo.

**UNDECIDABLE register — recorded, never asserted (A12).** Loop passes per PR, resident @
loop-pass turns (mean and Σ), billed session-model tokens, requests per story, QA rounds, blocked
rate, review findings per round. Each is a distributional claim; n=1 with no matched control cannot
decide one.
