# NA-92 pilot obligation

NA-92's own implementation run is **not** the pilot, for two independent reasons, same shape as
NA-87/88/90/91: G changes the orchestrator's own step contracts, so this run executed on the
PRE-change contract; and `plugins/**` edits do not reach running agents at all — they read
`CLAUDE_PLUGIN_ROOT` (the cache), not the repo. An after-number from this run would measure the
old contract while reading as if it measured the new one. The real-corpus run this story ships
(`tools/sdlc-analyser/__tests__/work-placement.test.sh` plus the ad-hoc mechanism-validation run
recorded in `byte-accounting.txt`) exercised the instrument against transcripts produced under
the OLD inline QA-Step-6/7 and PE-Step-6.5 contracts. It validates that the tool resolves a real,
large, three-tier corpus without silently dropping a tier — it is not pilot evidence, and it must
never be presented as any.

Pilot selection rule — the first Jira story satisfying ALL of, in this order, no discretion:

```text
pilot := the FIRST Jira story satisfying ALL of:
  (a) TRIAGE=full            # story points > 3, the project-context lightweight threshold
  (b) run end-to-end through /sdlc:auto   # not /impl alone, not /review — all three units must fire
  (c) started AFTER: NA-92 merged to develop
                     AND `pnpm nx release version -p sdlc` has run
                     AND the CLAUDE_PLUGIN_ROOT cache is updated to that released version
                     AND .claude/.sdlc-plugin-root points at it
  (d) NOT authored by NA-92 and NOT another NA-76 child   # the programme must not measure itself
  (e) its diff contains at least one .claude/project/docs-manifest.md-tracked path
relaxation := if the first THREE stories satisfying (a)-(d) all fail (e), take the third and mark
              every G3 row NOT CAPTURED — no manifest-tracked change
record the chosen key verbatim in the merged PR body
```

The pilot MUST report, at minimum, using the same table shape as `measurement-block.txt`, with
every row filled or explicitly marked `NOT CAPTURED — <reason>`.

Binding pass conditions — **four, not eleven** (amendment A4; the spec's own pass-conditions
block still `ASSERT`s all eleven, but the spec's own prose — "What n = 1 can and cannot decide" —
says only four are decidable at n=1 with no matched control, and the prose is right):

```text
ASSERT subagentShare(G1) == 1.0 AND subagentShare(G2) == 1.0
ASSERT subagentShare(G3) == 1.0 OR G3 == NOT CAPTURED     # per relaxation (e)
ASSERT returnCapExceeded == false for all three units      # a round-trip is a FAIL, not a partial pass
ASSERT cacheReadRatio >= 0.94                              # absolute threshold, decidable at n=1
ELSE revert or re-sequence G — never trade the guardrail for instruction surface

RECORD, never ASSERT: avg resident, peak resident, tool-result bytes, exposure, requests,
   QA rounds, blocked rate, review findings, loop passes
   # every one is a distributional claim with no matched control; at n=1 a value inside the
   # 30-impl-session spread is absence of a visible regression, NOT evidence of improvement
```

**What n = 1 can and cannot decide, stated so a future reader cannot mistake a passing pilot for
proof of a cut.** The placement rows (`subagentShare`, `returnCapExceeded`) and the byte cap are
**binary** — one story decides them outright, because they are properties of the artifact
observed on a single run, not a distributional claim. Every "not increased" row — requests, QA
rounds, blocked rate, review findings, loop passes, and every resident/exposure/byte row — is a
**distributional** claim with no matched control. A pilot landing inside the spread of the
30-impl-session baseline is **absence of a visible regression**, not evidence of improvement. A
pilot report that marks these rows PASS instead of UNDECIDABLE has over-claimed, regardless of
what the numbers happen to say — AC-3 (QA rounds, blocked rate, review findings "not increased")
is undecidable at n=1 by construction, and no single pilot run can decide it. Record the number;
do not assert a verdict on it.

Failure of any of the four binding ASSERTs -> **revert or re-sequence G. Never trade the
guardrail for instruction surface** (AC-2, verbatim). AC-5's 4.2% figure — and this spec's own
6.92% / 6.14% claim — stays **uncounted** toward the programme's stretch AC-1 until the pilot
passes every one of the four gates. Record the pilot's chosen key in the merged PR body (AC-4)
and comment it on NA-92, so the obligation cannot be silently dropped.
