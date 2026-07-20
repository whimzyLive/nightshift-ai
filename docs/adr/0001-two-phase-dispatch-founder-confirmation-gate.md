---
status: accepted
agents: [ai-enablement-engineer, knowledge-engineer]
source-stories: [NA-43, NA-52, NA-54, NA-55, NA-57]
---

# 0001. Two-phase dispatch for founder-confirmation gates

## Status

Accepted

## Decision

We will implement every plugin pipeline that requires a founder to review and confirm
content before an irreversible write (branch/commit/PR) as two separate subagent
dispatches, never one: **Phase 1** drafts candidate content and returns it, writing
nothing to disk; the **founder-confirmation gate runs at the command layer**, between
the two dispatches; **Phase 2** is a fresh dispatch — with no memory of Phase 1 or the
gate — that receives the founder-confirmed content verbatim and writes exactly that,
never re-drafting.

## Context

A dispatched subagent runs to completion and returns; it cannot pause mid-turn for
interactive human input. Any pipeline that needs a human decision point before a
destructive/irreversible action (writing files, creating a branch, opening a PR) must
therefore locate that decision point somewhere the harness can actually pause — which is
only possible between two separate dispatches, driven by the invoking command. This
constraint first surfaced for `/sdlc:analyze`'s scan-then-apply split and was
subsequently re-derived, independently, for the ADR pipeline (`knowledge-engineer` +
`/sdlc:adr`, NA-43) and then explicitly mirrored again for the docs-sync, release, and
seed pipelines (NA-52/54/55).

## Alternatives Considered

### Single dispatch with an in-session pause/resume primitive

- Pros: one dispatch, simpler mental model, no need to re-pass drafted content across a
  dispatch boundary.
- Cons: no such primitive exists in this harness — a dispatched subagent cannot block for
  interactive input mid-turn. Not actually available.

### Command layer drafts content itself, agent only writes

- Pros: avoids a "draft, discard, redraft" risk entirely since there's only ever one
  drafting pass.
- Cons: moves domain-specific authoring (ADR bodies, doc scaffolds, changelog copy) out
  of the specialized agent and into the generic command layer, which has none of the
  agent's skill-loaded authoring context (`writing-adrs`, `writing-docs`). Would require
  duplicating those skills' logic into the command itself.

### Two dispatches, but Phase 2 re-drafts from the same brief instead of receiving verbatim confirmed content

- Pros: simpler Phase 2 prompt (just "the same task again").
- Cons: no guarantee Phase 2's redraft matches what the founder actually reviewed and
  approved — defeats the purpose of a confirmation gate entirely. Explicitly rejected;
  every implementation of this pattern passes Phase 1's exact confirmed output into
  Phase 2's prompt, verbatim.

## Consequences

- Every pipeline needing a confirm gate follows one well-understood, already-proven
  shape, instead of each new command/agent pair re-deriving the split from scratch.
- Phase 2 dispatches are stateless and must be handed the confirmed content explicitly
  (inline or via session temp-dir files) — the command layer carries a real
  responsibility to pass this payload faithfully; a dropped or mangled handoff silently
  produces content the founder never actually approved.
- Adding a new gated pipeline is now a known recipe (draft/gate/write) rather than a
  fresh design question, at the cost of the mild ceremony of two dispatches instead of
  one for every gated flow.
- Revisit this decision if the harness ever ships a genuine mid-dispatch human-input
  pause primitive — at that point a single-dispatch flow may become both simpler and
  strictly safer (no verbatim-handoff risk).
