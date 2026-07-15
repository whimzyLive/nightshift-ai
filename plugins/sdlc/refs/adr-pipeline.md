# ADR pipeline

Shared draft → propose-tags → founder-confirm → write → regenerate-index → commit/PR protocol for
`/sdlc:adr`, referenced by both `agents/knowledge-engineer.md` and `commands/adr.md` so the
contract lives in exactly one place. Neither file re-inlines this logic — both summarize and link
back here.

## 1. Purpose + ownership note

This is the single-source pipeline for `/sdlc:adr`. All `docs/adr/**` writes land under paths
resolved from the consumer repo's `.claude/project/project-context.md`. In this SDLC repo itself,
any write that touches `plugins/**` (plugin-authoring, not a plain ADR run) stays within the
`ai-enablement-engineer` write-scope — see the Active-guard scope note in the agent's First steps.

## 2. Two-phase dispatch (split across the confirmation boundary)

A dispatched subagent runs to completion and returns — it cannot pause for interactive human
input. So the founder-confirmation gate cannot live inside the `knowledge-engineer` dispatch; it
lives at the **command layer**, between two separate dispatches of the same agent. This is the
same split `/sdlc:analyze` uses for its scan-then-apply flow.

**Phase 1 — draft & return (writes nothing):**

1. Draft candidate ADR(s) from the `writing-adrs` template: full body (Title, Status `proposed`,
   Decision, Context, Alternatives Considered, Consequences) + YAML frontmatter (`status:
proposed`, `agents: [...]`, `source-stories: [...]`).
2. Propose `agents:` routing tags for each candidate — the sdlc agent identifier(s) whose future
   work the decision constrains.
3. **(distill only)** Build the per-candidate deletion list: for each candidate, the exact memory
   entries proposed for deletion (file path + entry heading/anchor + verbatim text), subject to
   the [`shared.md` audience-preservation rule](#7-sharedmd-audience-preservation-rule).
4. Return the drafted ADR(s), proposed tags, and (distill) the deletion list to the command layer.
   **Nothing is written to disk in phase 1.**

**Founder-confirmation gate (command layer, NOT the agent — see §3).**

**Phase 2 — write only confirmed items:**

5. For each confirmed ADR: list `docs/adr/`, take `NNNN = max(existing) + 1` (four-digit,
   zero-padded, never reused — including numbers retired by superseded/rejected ADRs), write
   `docs/adr/NNNN-<decision-slug>.md`.

   **The founder-confirmation gate IS the acceptance moment.** Drafts presented at the gate (phase
   1 output) carry `status: proposed` — under discussion, not yet binding, per `writing-adrs`'
   lifecycle. The founder is the decision authority for this pipeline by design, so the gate's
   confirmation is the acceptance event: phase 2 writes each confirmed ADR with frontmatter
   **`status: accepted`** and body **`## Status` → `Accepted`** — never `proposed`. This is what
   makes the accepted-only write-path guard (`domain-agent-handoff.md`,
   `qa-engineer-playbook.md`) actually fire on pipeline-generated ADRs, and what makes distill's
   same-PR deletion of the superseded raw learning correct — the replacing record is binding at
   the moment the learning it replaces is removed, not merely proposed. If a confirmed ADR
   supersedes an existing `accepted` ADR, phase 2 also flips that old record's `status` to
   `superseded` and adds the two-way cross-links (old → "Superseded by ADR-NNNN", new →
   "Supersedes ADR-NNNN") in the same write, per `writing-adrs`' supersede flow — the old decision
   was still operative right up to this same acceptance moment, so both flips happen together,
   never one ahead of the other.

6. Regenerate `docs/adr/index.md` — see [§10 Index Regeneration algorithm](#10-index-regeneration-algorithm-docsadrindexmd).
7. **(distill only)** Delete the founder-approved learnings from their source memory files in the
   same PR (git history preserves the deleted text) — see [§8 Deletion-on-promotion](#8-deletion-on-promotion).
   Seed mode skips this step entirely.
8. Commit via the `conventional-commit` skill, push the branch, self-raise the PR via `gh` /
   `raise-pr.sh`.

## 3. Founder-confirmation gate is at the command layer, NOT in the agent

State this explicitly because it is easy to get backwards: the gate is not something
`knowledge-engineer` runs. It lives in `commands/adr.md`, between the phase-1 and phase-2
dispatches — identical in spirit to `/sdlc:analyze`'s "report, then apply only after explicit
human confirmation" split. The command presents each drafted ADR, its proposed `agents` tags, and
(distill) the exact memory entries slated for deletion, then waits for the founder. The founder
may edit tags, reject individual candidates, or adjust/veto specific deletions. Confirmation
covers drafts AND deletions together — nothing is deleted that the founder did not see and
approve. If the founder confirms nothing, the command writes nothing and exits cleanly (no
branch, no PR, no phase-2 dispatch).

## 4. Distill evidence protocol

Evidence sources (cluster across all of these):

| Source                                 | Access                                                  |
| -------------------------------------- | ------------------------------------------------------- |
| `.claude/memories/agents/*.md`         | Read (per-agent learning archives)                      |
| `.claude/memories/reviews/patterns.md` | Read (QA review-pattern audit log)                      |
| PR review threads                      | `gh` (e.g. `gh pr list` / `gh api` for review comments) |
| Commit history                         | `git log`                                               |
| claude-mem observations                | `observation_search` / `get_observations` MCP tools     |

**Evidence contract.** Every distilled candidate MUST cite evidence — but the citation KIND
depends on the occurrence's source, so an empty observation DB never blocks a well-evidenced
candidate:

- **claude-mem-sourced occurrences** — cite the claude-mem observation ID(s). Observation IDs are
  required ONLY for occurrences that came from claude-mem.
- **Repo-native occurrences** — cite the Jira story key(s), PR review thread(s), and/or commit
  SHA(s) that evidence the occurrence. No observation ID is required for these.
- A candidate satisfies the evidence gate when each of its cited occurrences carries at least one
  valid citation of the appropriate kind. A candidate may mix claude-mem and repo-native
  occurrences.
- **Empty observation DB → gate still satisfiable.** When claude-mem returns zero observations, a
  candidate evidenced entirely by repo-native citations (story keys / PR threads / commit SHAs)
  fully satisfies the evidence contract — repo-native evidence is the primary source, not a
  fallback. `source-stories` is populated from cited story keys regardless of whether any
  observation IDs were available.

## 5. claude-mem gates (environment, not data)

- **Tools absent → halt.** If the claude-mem MCP tools (`observation_search` /
  `get_observations`) are not available in the session (the plugin is not installed / not
  whitelisted), distill mode halts with a clear message, e.g.: `claude-mem tools unavailable —
/sdlc:adr --distill requires the claude-mem plugin; install it or use seed mode`. It does not
  silently proceed without them.
- **Tools present but DB empty → non-fatal.** A zero-result observation search is not an error —
  per §4, a candidate carried entirely by repo-native citations still fully satisfies the evidence
  contract.

These two conditions are distinct: tools MISSING is an environment halt (the protocol cannot run
at all); tools present but the DB EMPTY is a warning-and-continue (the protocol runs fine on
repo-native evidence alone).

## 6. Promotion criteria (distill)

A clustered learning is promoted to an ADR candidate iff it meets at least one of:

| Criterion          | Definition                                                                                                       |
| ------------------ | ---------------------------------------------------------------------------------------------------------------- |
| Recurrence         | Recurs across ≥ 2 cited occurrences, each backed by a citation of the appropriate kind.                          |
| Cross-agent        | The pattern spans more than one sdlc agent's domain.                                                             |
| Durable convention | A stable convention future work must follow, even if seen once, because it is expensive to reverse or re-derive. |

Candidates failing all three are NOT promoted — report them as "below threshold" and leave them in
memory untouched.

## 7. `shared.md` audience-preservation rule

`.claude/memories/agents/shared.md` is readable by every agent; a per-agent ADR index section is
read only by the agent(s) named in its `agents:` tag. Deleting a learning from `shared.md` and
replacing it with an ADR routed to only a subset of agents would narrow its visibility from
all-agents down to tag-list-only. Therefore:

- A learning promoted **from `shared.md`** may be deleted only when the replacing ADR preserves
  the audience — i.e. the ADR is either tagged with **every** agent the shared learning was
  relevant to, OR routed to the **`General`** section (which every agent reads via the read-path
  integration).
- Otherwise the `shared.md` entry STAYS — the ADR is still written as the canonical record, but
  the raw shared learning is not deleted, so no audience is silently starved of a learning it
  previously saw. The phase-1 deletion list must reflect this: a `shared.md` deletion is offered
  only when the audience-preservation condition holds.

## 8. Deletion-on-promotion

On write of a confirmed promoted candidate (phase 2, step 7), delete the founder-approved raw
learning entries from their source memory files in the same PR — git history preserves the
deleted text, so nothing is actually lost, only superseded by the canonical ADR. The deletion is
subject to (a) the founder gate — it only happens for entries that appeared in the phase-1
deletion list and were confirmed, and (b) the `shared.md` audience-preservation rule above. Seed
mode never deletes anything (there is no corpus mining, so there is nothing to delete) — this step
applies to distill only.

This cross-agent memory write is sanctioned as **Exception 2** in
[`analyze-protocol.md`'s memory-ownership rules](analyze-protocol.md#memory-ownership-exceptions)
— see that anchor for the canonical statement of the exception.

## 9. Seed-mode `source-stories` scoping

Seed mode formalizes a founder-known pattern inline — there is often NO originating Jira story. A
seed-mode ADR MAY carry an empty or omitted `source-stories` list (or a single optional
founder-supplied key when one genuinely applies). The `writing-adrs` skill's self-review checklist
item "`source-stories` lists the motivating Jira key(s)" scopes to **distill** mode — where
evidence is mined from story-keyed occurrences — not to seed. A seed ADR with no `source-stories`
is not flagged incomplete.

## 10. Index Regeneration algorithm (`docs/adr/index.md`)

Deterministic, fully derived from ADR frontmatter — never hand-authored, per `writing-adrs`. The
agent executes this as a prose algorithm inline (no committed script):

1. **Read** — list `docs/adr/`, read the YAML frontmatter of every `NNNN-*.md` file (skip
   `index.md` itself).
2. **Group** — one section per distinct agent name that appears in any ADR's `agents:` list, plus
   one `General` section for every ADR whose `agents` list is empty or omitted (so no ADR is ever
   dropped from the index). An ADR routed to N agents appears under each of those N sections.
3. **Sort sections** — alphabetical by agent name, with `General` last.
4. **Sort within a section** — ascending by `NNNN`.
5. **Line content** — each listing carries the ADR's number, title, and status:
   `- [NNNN. Title](NNNN-slug.md) — <status>`.
6. **Write** — overwrite `docs/adr/index.md` with the regenerated content.

Regeneration MUST be idempotent — running it twice with no ADR change yields a byte-identical
file. This is the deterministic-index open question's resolution: a prose algorithm, not a
committed script, matching this plugin's "instructions not code" style.

## 11. Cross-reference

The founder-gated distill deletion of promoted learnings from any agent's memory file (§8) is
sanctioned by **Exception 2** in `analyze-protocol.md`'s memory-ownership rules — see
[`analyze-protocol.md#memory-ownership-exceptions`](analyze-protocol.md#memory-ownership-exceptions).
That is the canonical statement; this ref and `agents/knowledge-engineer.md` both point back to it
rather than restating it.
