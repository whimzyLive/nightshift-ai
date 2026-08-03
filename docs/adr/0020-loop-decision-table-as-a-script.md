---
status: accepted
agents: [ai-enablement-engineer, platform-engineer]
source-stories: [NA-93]
---

Artifact encoding contract: unpadded tables, no section dropped, one-line N/A, verbatim contracts, rationale as annotation, prose < 10 lines between headings. plugins/sdlc/refs/artifact-encoding.md

# 0020. Loop decision table as a deterministic script, not a Haiku subagent

## Status

Accepted.

## Decision

We will ship the `sdlc:loop` probe-and-decide body — `commands/loop.md` Step 3 + Step 4 and
`refs/loop-modes.md` CI-1 + CI-2 — as a deterministic script, `plugins/sdlc/scripts/loop-decide.sh`,
not as a dispatch to a cheap (Haiku-class) subagent. This is a deliberate, stated deviation from
AC-1's literal wording, ruled by the founder at the spec gate, 2026-08-01. The reasoning, verbatim:

```text
the decision table is a pure function of a bounded integer tuple   # 1,458 enumerable cases
a script is exactly equivalent, costs ~0 context, and cannot mis-decide
a script is +0 on instruction surface -> it is EXECUTED, never READ
routing to a model buys nothing and adds a failure mode -> merging an unreviewed PR, or halting
   a healthy one
therefore: cheap := a script, not a cheap model
```

Precedent: NA-92's G3 shipped `scripts/docs-sync-gate.sh` over a subagent dispatch for the same
reason, recorded in ADR 0019 — a gate that carries no judgement is strictly cheaper as a script
than as any model tier, including the cheapest one.

**The scriptable rule**, verbatim from the spec (`docs/superpowers/specs/NA-93.md`):

```text
scriptable := a unit of work that (a) reads only script output or files already on disk,
              (b) applies a fixed, first-match-wins table over integers,
              (c) produces a token from a closed enum, and
              (d) performs NO side effect of its own
scriptable -> a contract-line script; emit the block below and nothing else; exit 0 always
NOT scriptable -> stays at the top level on the session model, no exception:
   /review-fix and the in-session REVIEW_CMD      # they edit, push, and post
   loop-budget.sh init/check                      # D8 — the budget script already owns the budget
   the review marker write                        # the top level owns what it will read back
   the --on-clean hook                            # the only irreversible action in the loop
   session-complete.sh                            # owns the single slot release
   the clean-predicate re-check                   # H3 — re-derived from FIELDS, not trusted from
                                                   # the script's own DECISION token
```

**Fail-safe direction:** `unresolvable -> wait`, never `clean`, never `halt`. `wait` is the only
decision in the enum with no irreversible effect **and** a bound — `loop-budget.sh` stops a
wait-looping pass at 1200 s idle or 30 passes — so a probe failure degrades to a bounded stall with
a printed `BLOCKED_BY`, never to a merge and never to a premature halt. This is distinct from the
table's own catch-all: a probe that resolves but matches no row still selects rule 7 → `halt`,
unchanged from before this story — that is the table's design, not a fail-safe path, and H does not
touch it.

**The revert-lever choice, and why no zero-deploy dial is offered.** The lever is
`git revert <H-sha>` followed by `pnpm nx release version -p sdlc` and a cache update; H's diff
(`commands/loop.md`, `refs/loop-modes.md`, `scripts/loop-decide.sh`, `scripts/__tests__/`,
`tools/sdlc-analyser/`, `.github/workflows/ci.yml`, `docs/adr/`) shares no hunk with workstreams E,
F or G, so the revert applies cleanly over any of them. No opt-in gate and no zero-deploy dial is
offered: a dial would force `commands/loop.md` to retain the inline table as a fallback path,
pushing the byte delta positive and leaving the script path permanently unexercised in production
— the same argument that defeated the withdrawn `SDLC_LOOP_MODEL` dial. A model's behaviour is
unpredictable enough to justify a dial; a script's behaviour is pinned by an exhaustive 1,458-case
gate, so the dial buys nothing and costs the whole byte claim.

## Context

The `sdlc:loop` pass currently re-loads the full probe-and-decision body — 12,446 B ported from
`commands/loop.md` Step 3+4 and `refs/loop-modes.md` CI-1+CI-2 — into the session model's resident
context on every pass, to execute a decision that is a pure function of a bounded integer tuple
(1,296 Copilot-review cases × 162 in-session-review cases = 1,458 total). The story's own title and
AC-1 name a "cheap (Haiku-class) subagent" as the target for this offload. A subagent dispatch,
even on the cheapest tier, still costs a full dispatch-instruction floor, still consumes a request,
and — because the decision routes whether a PR merges or the loop halts — still introduces a
failure mode a deterministic script cannot have: a model can merge an unreviewed PR or halt a
healthy one on a misread; a script executes the same first-match-wins table every time, and the
table's correctness is now checked exhaustively (H-Gate-2) rather than trusted to a per-call
judgement.

`knowledge-engineer` is not an active agent in this repo — `.claude/project/agents/` holds exactly
three overrides (`ai-enablement-engineer`, `platform-engineer`, `web-engineer`) — so this ADR is
`ai-enablement-engineer`'s to author, per amendment A2 of the implementation plan and consistent
with ADR 0019's own assignment.

Two mechanism findings surfaced while building H, recorded here for the next story that needs
genuine judgement in a hot loop rather than a pure function of integers:

- **The `Agent` tool's `model` parameter** exists as `enum(["sonnet","opus","haiku","fable"])` at
  bundle offset 234,665,054 (harness bundle `2.1.220`); `"haiku"` resolves to `claude-haiku-4-5`,
  priced at $1/$5 per MTok versus Opus 5's $5/$25. H dispatches no agent at all, so this parameter
  is unused here — it is recorded because a future story that genuinely needs judgement, not a
  pure integer function, will want it.
- **`run_in_background` defaults to `true`.** A dispatch whose caller needs the result back must
  pass `run_in_background: false` explicitly; omitting it produces a **silent hang**, not an error
  — the caller simply never observes completion. H needs no dispatch at all, so this trap did not
  bite this story, but it is exactly the shape of mistake a future dispatch-based successor to this
  decision would make on the first attempt.

**Enumeration coverage is not production coverage.** H-Gate-2 proves all 1,458 domain cases, run
through the real `loop-decide.sh`, select the same rule as a golden extracted from the pre-change
tables by a different agent in an earlier phase (`sourceSha=433120dafa2929048a740f427a5e82fe7f802760`,
`sourceBytes={"plugins/sdlc/commands/loop.md": 17544, "plugins/sdlc/refs/loop-modes.md": 18851}`,
both independently confirmed via `git show <sourceSha>:<path> | wc -c` in this worktree). That is a
genuine pre-ship correctness proof — the first on this epic that escapes NA-88 D11's
self-confirming shape, because the golden's author did not write the script it is compared against.
It is **not** evidence that the table itself was ever right in production: replaying the real
session corpus (`tools/sdlc-analyser/loop-decision.py --replay`, 107 top-level + 567 T2 + 890 T3 =
1,457 subagent transcripts at the time of this ADR) finds only 97 real `loop-status:` snapshots
across 10 distinct field tuples, and `observed.rulesWithZeroEvidence == ["1","5","6","7"]` — four of
the sixteen table rows, including rule 6 (failing checks → halt) and rule 7 (catch-all → halt), the
two that would matter most if wrong, have never fired on a real PR. This assertion exists precisely
to keep that gap visible on every future run, not to close it.

## Alternatives Considered

### Dispatch to a Haiku-class subagent, matching AC-1's literal wording

- Pros: satisfies AC-1 with no stated deviation; a model dispatch could in principle absorb a
  future rule change without a code edit, and gives a uniform "route to cheap tier" mechanism
  across the epic's workstreams.
- Cons: the decision table is already a closed, first-match-wins function over eight bounded
  integer fields — there is no judgement for a model to add. A dispatch still pays a full
  subagent-instruction floor and a request per pass, still needs the `run_in_background: false`
  and `model` parameter handling recorded above, and — because this decision routes whether a PR
  merges or the loop halts — introduces exactly the failure mode ADR 0019's `NOT offloadable`
  category exists to name: a model can mis-route a routing decision; a script executing a table it
  did not choose cannot.

### Leave the table inline in `commands/loop.md` / `refs/loop-modes.md`, pursue only prose trimming

- Pros: no new script or test surface to maintain; smaller diff.
- Cons: measured at HEAD, the decision-table prose (12,446 B) is essentially the entire required
  cut against the 4,044 B / 9,395 B budget gaps on `loop.md` and the combined `loop.md` +
  `loop-modes.md` cap respectively; trimming prose without relocating the table could not reach
  either cap without deleting decision rows the story is explicitly forbidden from touching.

### A zero-deploy dial (env var) to fall back to the inline table

- Pros: an instant, no-release rollback path if the script mis-decides in production.
- Cons: requires `commands/loop.md` to retain the inline table as a permanent fallback branch,
  which pushes the byte delta positive (defeating the story's entire budget claim) and leaves the
  script path unexercised whenever the dial defaults to the old behaviour. The clean guard (H3)
  already provides runtime containment for the one irreversible branch independent of any dial, and
  the revert lever (`git revert` + release + cache update) is a clean, single-commit rollback given
  H's diff shares no hunk with any other workstream.

## Consequences

- The per-pass top-level instruction surface drops from `loop.md` = 17,544 B / combined `loop.md` +
  `loop-modes.md` = 36,395 B to `loop.md` = **13,421 B** (cap 13,500, 79 B slack) and combined =
  **26,955 B** (cap 27,000, 45 B slack) — measured directly in this worktree, no rung of the
  fallback ladder used. The `qa-engineer-playbook.md` + `principal-engineer-playbook.md` pair stays
  at **73,386 B**, unchanged (G's 318 B of slack was not H's to spend and was not touched); both
  `domain-agent-handoff.md` byte pins (`## Context reuse` = 868 B, `## Bounded reads` = 1,005 B)
  are unchanged.
- The decision table now has a genuine pre-ship correctness proof (H-Gate-2, all 1,458 cases,
  `mismatches=0`) that the prior inline-prose form never had and could not have had — a markdown
  table read by a model each pass is never mechanically checked against anything.
- The table's real-world correctness on rules 1, 5, 6 and 7 remains **unestablished** — H-Gate-2
  proves the port, not the design, and `rulesWithZeroEvidence` is the standing, permanent reminder
  of that gap. A future incident on one of those four rules is not a regression this story
  introduced; it is a pre-existing risk this story made newly visible.
- A future story that needs genuine per-call judgement in a hot loop (not a pure function of a
  bounded tuple) inherits two recorded traps rather than rediscovering them: the `run_in_background`
  default and the `model` enum's bundle location and pricing tier.
- This story's own implementation run cannot measure the runtime spend claim: H changes the loop
  pass's own contract, so this run executed the pre-change contract throughout, and `plugins/**`
  edits do not reach running agents at all — they read `CLAUDE_PLUGIN_ROOT` (the plugin cache), not
  the repo. Every runtime row (loop-pass turns, invocations per pass, `cacheReadRatio` after,
  `returnCapExceeded`, clean-guard rejections) is **NOT CAPTURED**, with a named successor pilot
  (`docs/superpowers/plans/NA-93-measurements/pilot-obligation.md`) — the first `TRIAGE=full` story
  run end-to-end through `/sdlc:auto` after this ADR merges, the plugin is released, and the cache
  points at that release.
- **Confidence.** High that the byte-cut and the 1,458-case equivalence claims hold — both are
  measured directly in this worktree against a golden whose provenance is mechanically asserted,
  not estimated. Low, by construction, on whether rules 1, 5, 6 and 7 are correct in production —
  there is no evidence either way, and this decision does not manufacture any. Revisit this
  decision, or revert per the H4 lever, if the named successor pilot's `cacheReadRatio` falls below
  0.94 or any clean-guard rejection or `RULE=unresolvable` occurrence is observed without its
  `BLOCKED_BY` reason recorded — per AC-2, never trade the guardrail for instruction surface.
