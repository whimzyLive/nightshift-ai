# NA-91 Gate-3 pilot obligation

NA-91's own implementation run is NOT the pilot. It executed on the pre-change contract, and
`plugins/**` edits do not reach running agents at all — they read the plugin cache, not the repo.
An after-number from this run would measure the old contract while reading as if it measured the new.

Pilot selection rule — the first story satisfying ALL of:

```text
ASSERT NA-91 has merged to develop
ASSERT the sdlc plugin has been released AND the cache updated to that version   # else the run reads the OLD text
ASSERT the harness re-invokes the printed <<<SDLC_NEXT_INVOCATION:...>>> line    # else set SDLC_BOUNDARY_OFF and defer
ASSERT it is a TRIAGE=full story run end-to-end through /sdlc:auto
ASSERT NA-91 did not author it
```

The pilot MUST report, at minimum:

```text
inheritedShare on the pilot's top-level transcript      (GATE: < 0.10; baseline pooled 0.4018)
cacheReadRatio                                          (GATE: >= 0.94; baseline 96.64%)
avg resident / peak resident                            (GATE: neither increased)
requests, QA rounds, blocked rate, review findings, loop passes   (GATE: none increased)
inheritedShare WITHIN the new tail session               (a follow-up only if it exceeds 0.10)
the corpus partition counts: subagentTranscripts must be 0
```

Failure of any gate → **revert or re-sequence F. Never trade the guardrail for a smaller
instruction surface** (AC-2, verbatim). `SDLC_BOUNDARY_OFF` is the runtime lever; a code revert is
the fallback.

One run cannot move AC-1's dollar figure (8-pt IQR $68.72). F's 7.0% cut-rate is NOT counted toward
the programme's AC-1 until this pilot passes every gate (AC-5). Record the pilot's key in the merged
PR body (AC-4) and comment it on NA-91, so the obligation cannot be silently dropped.

## Baseline divergence, carried forward unaltered

The baseline captured in Task 1.5 (`context-residency-before.txt`) measures pooled `inheritedShare`
at 40.18% (n=75) against the merged spec's 34.6% (n=86) — +5.58pp, outside the spec's own ±5pp
band. The per-transcript median diverges further: 11.74% here vs the spec's 49.6% (p25 0.00% vs
31.1%, p75 52.79% vs 57.2%), largely because 35 of the 75 sessions never raise a PR (spec/plan/
refine-only sessions) and score `inheritedShare` 0.0, which pulls the per-session median down harder
than the pooled, exposure-weighted figure. `cacheReadRatio` (96.64%) matches the spec's figure almost
exactly. The pilot's `< 0.10` gate is evaluated against whichever baseline number is in force at
pilot time — this divergence is stated plainly here rather than adjusted to match the spec.
