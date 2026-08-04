---
status: accepted
agents: [ai-enablement-engineer, platform-engineer]
source-stories: [NA-81]
---

Artifact encoding contract: unpadded tables, no section dropped, one-line N/A, verbatim contracts, rationale as annotation, prose < 10 lines between headings. plugins/sdlc/refs/artifact-encoding.md

# 0021. Plan-doc slicing as a deterministic script, not a pasted-content instruction

## Status

Accepted.

## Decision

We will ship `plugins/sdlc/scripts/plan-slice.sh` — a deterministic per-phase slicer and
all-phase task-checklist extractor with a five-key `eval`-safe stdout contract — and rewrite the
two remaining plan-doc paste-the-content instructions (`qa-engineer-playbook.md:132-133`,
`principal-engineer-playbook.md:328`) to name a path instead. Consistent with ADR 0019 and
ADR 0020, a script is chosen over a subagent dispatch: phase-boundary extraction from a plan doc
is a deterministic function of a regex and a fence-tracking boundary rule, not a judgement call —
a script costs ~0 context, cannot mis-decide a phase boundary, fails machine-detectably, and is
**+0 on instruction surface because it is executed, never read**.

**The phase-heading grammar is widened beyond `agents/tech-lead.md:138`.** The template-pinned
form `^## Phase <digits> (—|–|-) <text> \[<agent-name>\]$` matches only 11 of 41 real plans at
measurement time; five real delimiter forms exist in the corpus (bracket, backtick-after-·,
parens+backtick, bare parens, backticked-brackets), and the current-era plans (NA-86…NA-89) all
fail the pinned form because they write the owner after a middle dot, not in brackets. The
grammar this story ships is `^##[ ]+Phase\b` plus an AGENT_SET token found anywhere in the
heading line, decoration-insensitive, ordinal optional. `principal-engineer` is deliberately
excluded from AGENT_SET: an orchestrator-owned phase, such as NA-88/NA-89's
"## Phase 4 — Merge-gate transcription · orchestrator (`principal-engineer`)", is never a domain
agent's to receive. `agents/tech-lead.md`'s own template is unchanged by this story — the slicer
is made tolerant of what plans actually look like, not the other way round.

**Fail-safe direction: always widen, never empty.** Any plan doc the slicer cannot resolve to an
agent-owned phase returns `SLICE=<the plan path itself>` at exit 0 — the agent reads the whole
plan, exactly today's behaviour, never worse. An empty slice is never a valid output. 10 of the 42
plans in the corpus (including this one, on the fallback grammar for other agents' phases) take
this path; it is still a net win, because the fallback replaces a pasted-content instruction with
a path.

**Reviewer-slicing is deferred, deliberately.** Site C (`qa-engineer-playbook.md`) ships
path-not-paste only — the reviewer's input stays byte-identical to today, whole-plan grounding
retained. Slicing what a reviewer sees is a quality risk NA-76's own instruments cannot detect:
"review findings per round must not increase" cannot distinguish better code from a blinder
reviewer. Revisit only with QA-rounds-to-clean **and** post-merge defect rate as a paired gate,
never on the existing guardrail alone.

**`$WORKTREE` resolution lives inside the script, not the playbook.** On `/auto`'s Workflow A the
plan doc is committed onto `feat/<STORY-KEY>` (`commands/auto.md`, step A2.2) and does not exist
in the primary checkout, which is the orchestrator's CWD for the whole run
(`principal-engineer-playbook.md`). Handing the bare relative path there would yield
`ERROR=plan-not-found` on every `/auto` story. `plan-slice.sh` resolves, first hit wins: the path
as given; then `$WORKTREE/<path>` when `$WORKTREE` is set and readable; otherwise
`ERROR=plan-not-found` at exit 2. This lives in the script because script bytes are `+0` on
instruction surface, while the playbook pair had only 259 B of slack left after this story's own
spend.

**The `eval` boundary is quoted and status-checked, not assumed.** Every value in the five-key
stdout contract (`MODE`, `SLICE`, `TASKS`, `PHASES`, `GRAMMAR`) is single-quoted at emission
(`shq()`, reused verbatim from `loop-decide.sh`), and no key shadows a standard shell variable
(the `PATH=` precedent from ADR 0020/NA-93 A8). Separately, and just as load-bearing: a consumer
must **capture the script's stdout, test its exit status, and only then `eval` it** —
`eval "$(bash plan-slice.sh …)" || STOP` is wrong, because `$(...)` discards the child's exit
status before `||` ever sees it, so an `ERROR=plan-not-found` (exit 2) becomes a silent,
contract-less dispatch. `principal-engineer-playbook.md`'s Step 4 invocation and the plugin's
`plan-slice.test.sh` (G-8) both encode capture-then-test-then-eval as the only correct form.

**The `checklist` mode is a subagent-local win, not a top-level one.** `ac-verification.md`'s
dispatched verifier sources the `checklist`-mode slice when supplied and reads the whole plan doc
only on `GRAMMAR=unmatched`, keeping its own read inside its 4,000 B return cap on 100 KB plans
(avg measured 74,981 B → avg 4,754 B on NA-86…NA-93). This is priced separately from the
top-level playbook-byte ledger below — it never appears in that ledger, and does not need to.

`knowledge-engineer` is not an active agent in this repo — `.claude/project/agents/` holds exactly
three overrides (`ai-enablement-engineer`, `platform-engineer`, `web-engineer`) — so this ADR is
`ai-enablement-engineer`'s to author, consistent with ADR 0019's and ADR 0020's own assignment.

## Context

Two of the pipeline's four plan-doc placement sites still pasted the plan's full content into a
top-level or reviewer-facing prompt on every dispatch or review round: `principal-engineer`'s
Step 4 domain-agent dispatch pasted "the full phase section from the plan, verbatim" once per
phase, and `qa-engineer`'s review-round prompt pasted "the full content of" the plan doc once per
round — on a real 100 KB+ plan this is tens of thousands of bytes of prompt text repeated per
phase or per round. NA-76's earlier workstreams (NA-92, NA-93) had already moved comparable
per-pass table/gate logic off the model and onto a script for the same reason: a mechanical
extraction with no judgement component is strictly cheaper and more reliable as a script than as
any model tier. The spec that motivated this story pinned a phase-heading grammar and a corpus
match count against `agents/tech-lead.md`'s own plan template; both were measurably wrong against
the live corpus of 41 real plan docs, which uses five distinct delimiter conventions the template
does not name, three of which the current epic's own plans use.

## Alternatives Considered

### Dispatch a subagent to extract the phase / build the checklist

- Pros: could in principle tolerate a plan format the regex-based grammar has never seen, without
  a code change.
- Cons: phase-boundary extraction from a heading regex plus a fence-tracking rule is already a
  closed, deterministic function — there is no judgement for a model to add. A dispatch still
  pays a full subagent-instruction floor and a request per phase or per round, and — because a
  mis-extracted slice silently truncates a domain agent's own instructions — introduces a failure
  mode a script cannot have.

### Keep the narrow, template-pinned grammar from `agents/tech-lead.md:138`

- Pros: exactly matches the one bracket-only, ordinal-required template the plan-writing skill
  emits going forward; smallest possible grammar surface.
- Cons: measured against the real 41-plan corpus, it matches only 11 of 41 (27%) — 73% of real
  plans, including every plan this epic itself has produced (NA-86, NA-88, NA-89, all
  backtick-after-· form), would silently degrade to the whole-plan fallback. A grammar that fails
  the very plans the story's own epic writes is not a genuine improvement over doing nothing.

### Ship reviewer slicing alongside domain-agent slicing (extend Site C beyond path-not-paste)

- Pros: would cut the reviewer-facing prompt further, proportional to the domain-agent saving.
- Cons: NA-76's own success gate ("review findings per round must not increase") cannot
  distinguish a genuinely better implementation from a reviewer given less context to find
  problems in — a regression here would look identical to an improvement on the one instrument
  the epic has. Deferred, not rejected: revisit with a paired defect-rate gate the epic does not
  yet have.

## Consequences

- `principal-engineer-playbook.md` + `qa-engineer-playbook.md` combined stand at **73,445 B**
  against the pinned cap of **73,704 B** (259 B slack) — measured directly in this worktree after
  this story's full edit set (Site C's path-not-paste rewrite from an earlier phase, the Step 4
  invocation, the item-4 rewrite, and the approved 164 B harvest of a duplicated grounding-note
  instruction that prompt-contract item 6 already carried). `commands/loop.md` (13,421 B) and
  `refs/loop-modes.md` (13,534 B) are untouched, as are `domain-agent-handoff.md`'s two existing
  byte-pinned sections (`## Context reuse` = 868 B exactly, `## Bounded reads` = 1,005 B, both
  re-asserted after this story's own EOF append).
- Both remaining paste-the-content instructions are gone: `principal-engineer` dispatches a
  `SLICE=` path per phase instead of pasting the phase section, and `qa-engineer`'s reviewer reads
  the plan doc itself from a named path instead of receiving it pasted into the prompt.
- The real corpus this branch replays is 42 plan docs (41 pre-existing plus this one) — 32 matched
  (one or more agent-named phase heading present), 10 unmatched (whole-plan fallback), replayed
  row-by-row against a generated expectation file so a future corpus drift is caught mechanically,
  not by inspection.
- A future story that adds a sixth phase-heading delimiter form, or that changes AGENT_SET, has a
  single script to edit and a corpus-replay gate (G-10/G-11) that will fail loudly if the change
  regresses any of the 42 real plans — it does not need to re-derive the grammar from scratch.
- **What this does not prove.** Every gate in this story's own falsifiability register is authored
  by the same story that authors the artifact it tests — a green suite proves the author wrote
  what the author intended, not that a dispatched agent actually reads the `SLICE=` path it is
  handed rather than asking for the content anyway. That is a behavioural claim, and it is
  explicitly **NOT CAPTURED** by this run (see below).

**Confidence.** High that the byte ledger and the corpus-replay figures hold — both are measured
directly in this worktree against a corpus every fixture and golden was proven falsifiable
against. Low, by construction, on whether the new dispatch contract changes real orchestrator or
agent behaviour in production: `plugins/**` edits do not reach running agents until the plugin is
released and the cache is updated, and this run necessarily executed under the pre-change
contract throughout, so it cannot measure its own effect. Revisit this decision — or extend Site C
to reviewer slicing — only after the named successor pilot (the first `TRIAGE=full` story run
end-to-end through `/sdlc:auto` after this ADR merges, the plugin is released, and the cache
points at that release, measured via `tools/sdlc-analyser/work-placement.py` unit `P1`) reports
its `cacheReadRatio`, `SLICE`-read-vs-ask-for-content rate, and QA-rounds-to-clean figures.
