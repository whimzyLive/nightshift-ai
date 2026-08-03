---
status: accepted
agents: [ai-enablement-engineer, platform-engineer]
source-stories: [NA-92]
---

Artifact encoding contract: unpadded tables, no section dropped, one-line N/A, verbatim contracts, rationale as annotation, prose < 10 lines between headings. plugins/sdlc/refs/artifact-encoding.md

# 0019. Offload gate and verification steps to subagents

## Status

Accepted.

## Decision

We will relocate three leaf steps the top-level orchestrator currently executes inline — the QA
quality-gate run (Step 6), the AC/plan verification reads (Step 7), and the docs-sync gate
resolution (Step 6.5) — so their reads and command output land outside the orchestrator's own
transcript, while every decision those steps feed stays at the top level. The offload rule,
verbatim from the spec:

```text
offloadable := a unit of work that (a) only reads or runs commands, (b) produces a verdict
               expressible in <= its stated return cap, and (c) never needs to dispatch an agent
offloadable -> execute in a dispatched `general-purpose` subagent (or a script when the unit
               carries no judgment at all); return the verdict, never the raw input
NOT offloadable -> stays at the top level, no exception:
   any decision that routes the run (pass/fail, clean/blocked, which of the five docs buckets)
   any dispatch of a domain agent            # one-level nesting limit, ADR-0012
   any attestation about the PRIMARY CHECKOUT # a subagent cannot attest to its own isolation breach
```

Three things provably cannot move, no exception, under this rule:

1. **Any decision that routes the run** — pass/fail, clean/blocked, which of the five docs-sync
   outcome buckets applies. Moving the decision, not just the work that feeds it, would make the
   orchestrator's control flow depend on a subagent's judgment rather than its evidence.
2. **Any dispatch of a domain agent** — the one-level subagent-nesting limit (ADR-0012). A
   `general-purpose` subagent that itself dispatched `ai-enablement-engineer` or `platform-engineer`
   would be a second level of nesting this repo's orchestration model does not support.
3. **Any attestation about the primary checkout** — a subagent cannot attest that it did not
   corrupt the primary checkout, because the guard exists precisely to catch corruption a
   compromised or malfunctioning process might not itself report. `assert-workspace-clean.sh`
   stays at the top level, unchanged.

QA quality-gate mechanics move to `plugins/sdlc/refs/qa-gate-runner.md` (G1); AC/plan verification
mechanics move to `plugins/sdlc/refs/ac-verification.md` (G2); the docs-sync manifest and
change-size gate move to `plugins/sdlc/scripts/docs-sync-gate.sh` (G3). G1 and G2 are dispatched
via `Agent({ subagent_type: "general-purpose", ... })`; G3 ships as a deterministic script, not a
dispatch — a deliberate, stated deviation from the story's AC-1, whose literal wording calls for
all three units to be "dispatched to subagents." The reason: the docs-sync **work** is already
dispatched today (`principal-engineer-playbook.md:543` dispatches the `knowledge-engineer`
post-QA variant) — only the **gate that decides whether to dispatch** ran at the top level, and
that gate carries no judgment (three deterministic set operations with a fail-safe default).
Dispatching a subagent to decide whether to dispatch a subagent costs a full subagent instruction
floor to save a smaller one; the change-size gate exists specifically to avoid an unnecessary
dispatch. This trade is recorded here plainly, not hidden behind a claim that AC-1 is satisfied
by its literal reading — it is satisfied by intent (the docs-sync work already runs in a
subagent) via a cheaper mechanism than the AC names.

Every offloaded unit carries an explicit, capped return contract (G1 2,000 B, G2 4,000 B, G3
200 B), asserted by CI. A unit whose full output must come back to the top level has not been
offloaded — it has been round-tripped, at the cost of one extra dispatch for the same resident
bytes; `returnCapExceeded` is the round-trip detector and a `true` value fails the pilot, not just
a smoke test.

This decision does **not** supersede ADR-0012. ADR-0012 keeps the orchestration _roles_
(principal-engineer, qa-engineer) as inline playbooks, never dispatchable agents. This decision
moves three of those roles' _leaf steps_ into subagent-executed refs and a script; the roles
themselves, their control flow, and every routing decision stay exactly where ADR-0012 put them.

## Context

The top-level orchestrator session reads both playbooks whole on every impl run, and both stay
resident for the rest of it. Measured against the spec's corpus: `principal-engineer-playbook.md`
was read 34 times (1,249,256 B, 11.53% of top-level tool-result bytes); `qa-engineer-playbook.md`
28 times (852,473 B, 7.87%). The three candidate units' own command output is comparatively small
— G1's gate results average 477 B per call (n=217) — so the larger lever is not the output these
steps produce but the instruction bytes describing how to produce it: moving a step's mechanics
into a subagent-only ref removes that ref from the top-level read entirely, because the
orchestrator never reads it; only the dispatch prompt naming it does.

The programme this story belongs to (NA-76) tracks a combined-instruction-surface budget for the
two playbooks: `bytes(qa-engineer-playbook.md) + bytes(principal-engineer-playbook.md) <= 73,704`.
Measured at this story's base commit, the combined total was 78,454 B — 4,750 B over budget. As
shipped, the combined total is 73,386 B, a cut of 5,068 B (318 B of slack against the cap), reached
without using any rung of the plan's fallback ladder and without touching either byte pin in
`refs/domain-agent-handoff.md` (`## Context reuse` == 868 B exactly; `## Bounded reads` == 1,005 B,
both unchanged).

Two independent facts mean this story's own implementation run cannot measure whether the offload
contract is obeyed in practice: the run executes on the **pre-change** contract (the orchestrator's
own step instructions do not change until this PR is read by a future session), and `plugins/**`
edits do not reach running agents at all — they read `CLAUDE_PLUGIN_ROOT` (the plugin cache), not
the repo. Every runtime row this story could report is therefore `NOT CAPTURED`, with a named
successor pilot (`docs/superpowers/plans/NA-92-measurements/pilot-obligation.md`) — the first
`TRIAGE=full` story run end-to-end through `/sdlc:auto` after this ADR merges, the plugin is
released, and the cache is updated to that version.

ADR-0012 records a one-level subagent-nesting limit as accepted, based on a corpus check finding
0 of 1,447 subagent transcripts contain any further `Agent`/`Task` dispatch. The harness bundle at
2.1.220 tracks a `spawnDepth` field and propagates `--append-subagent-system-prompt` "to nested
subagents," which means the underlying capability may no longer be absent — but this story does
not re-test that claim, because G is designed to need no nested dispatch regardless of the answer.

## Alternatives Considered

### Dispatch G3 as a `general-purpose` subagent, matching G1 and G2 literally

- Pros: satisfies AC-1's literal wording with no stated deviation; uniform mechanism across all
  three units, simpler to explain and to audit.
- Cons: the docs-sync **work** this gate feeds is already dispatched (the `knowledge-engineer`
  post-QA variant); the gate itself carries no judgment — three deterministic set operations with
  a fail-safe default. Paying a full subagent instruction floor to decide whether to pay a smaller
  one is a net loss exactly in the case this gate exists to avoid.

### Add a new plugin agent definition for the gate-runner or the verifier

- Pros: a named agent could carry richer, persona-specific instructions and would be independently
  addressable in future dispatches.
- Cons: an agent definition's frontmatter `description` is injected into every session regardless
  of whether that session ever dispatches it — it lands **positive** on the always-loaded surface,
  which directly works against the instruction-budget goal this story exists to serve. Rejected on
  that basis alone; `subagent_type: "general-purpose"` with an explicit prompt contract achieves
  the same isolation at zero always-loaded cost.

### Re-test ADR-0012's one-level nesting limit as part of this story

- Pros: would resolve the open question the 2.1.220 `spawnDepth` tracking raises, rather than
  deferring it; a confirmed answer either way removes ambiguity for future offload work.
- Cons: re-testing whether subagents can dispatch further subagents reopens whether the QA and PE
  playbooks themselves could become dispatchable agents — a far larger architectural question than
  this story's three leaf-step relocations. G is designed strictly within the existing one-level
  limit and does not need the answer either way, so re-testing it here would expand scope without
  changing what ships.

### Leave all three units inline and pursue only prose-trimming to hit the byte budget

- Pros: no new refs or scripts to maintain; smaller, more contained diff.
- Cons: measured section-by-section, the movable prose (run mechanics, checklists, the defect
  regression-evidence contract, the manifest/change-size gate prose) accounts for essentially all
  of the required cut; trimming without relocating would either fail to reach the 4,750 B target
  or strip verification content the story's own non-negotiables (evidence over assertion) forbid
  cutting.

## Consequences

- The combined impl-path instruction surface drops from 78,454 B to 73,386 B (−5,068 B), moving
  the two playbooks from over budget to 318 B of slack under the programme's 73,704 B cap.
- Three new subagent-only artifacts (`refs/qa-gate-runner.md`, `refs/ac-verification.md`,
  `scripts/docs-sync-gate.sh`) and their test suites become part of the maintained surface; a
  future change to gate or verification mechanics must edit the correct file, not the playbook
  stub, and must re-verify the absence tokens the CI guard asserts stay unique.
- G3's script-not-dispatch shape is a permanent, stated inconsistency with G1/G2's dispatch shape
  and with AC-1's literal wording. A future reader comparing the three units side by side will see
  two `Agent()` calls and one `bash` invocation; this ADR is the pointer to why.
- The offload contract's actual observance — whether real sessions dispatch G1/G2 and route G3
  through the script rather than reverting to inline execution — is **not** established by this
  story. It is established, if at all, by the named successor pilot; every gate this story ships
  (`work-offload-budget.test.sh`, `docs-sync-gate.test.sh`, `work-placement.test.sh`) is a **smoke
  test on the artifact** (NA-88 D11), never a gate on agent behaviour, because each is authored by
  the same story that authors the thing it tests.
- The one-level subagent-nesting limit (ADR-0012) is not re-tested by this decision, despite the
  2.1.220 bundle's `spawnDepth` tracking suggesting the underlying capability may have changed.
  That question is deferred to a named successor story; this decision is unaffected either way
  because G never dispatches a domain agent from within a subagent.
- **Confidence.** High that the byte-cut claim holds — it is measured directly in this worktree,
  not estimated, and the falsifiability register (14 rows, `byte-accounting.txt`) was re-executed
  live rather than trusted from the plan. Moderate, not high, on whether the offload contract will
  actually be obeyed by real sessions: the mechanism-validation run this story ships exercised the
  instrument against a pre-change corpus, and cannot stand in for the pilot. Revisit this decision,
  or re-sequence/revert G, if the named successor pilot's `cacheReadRatio` falls below 0.94 or any
  unit's `returnCapExceeded` is `true` — per AC-2, never trade the guardrail for instruction
  surface.
