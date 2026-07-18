---
status: accepted
agents: [ai-enablement-engineer]
source-stories: [NA-26, NA-43, NA-44, NA-52, NA-57]
---

# 0003. Shared cross-file contracts get exactly one canonical statement, with every other site reduced to a pointer

## Status

Accepted

## Decision

We will state any mechanical rule or contract shared by more than one file in
`plugins/sdlc/**` (command/agent/ref files) exactly once, at one designated canonical
section, and reduce every other site that needs to reference it to a short pointer
(prose reference or anchor link) naming only what differs locally — never a full
independent restatement of the mechanics themselves.

## Context

Several plugin contracts (the `Skills loaded:` return-line semantics, the founder-gated
distill deletion exceptions, the two-phase-dispatch skeleton, the ADR-vs-docs-sync
dispatch branching) are each genuinely relevant to more than one file — the command that
dispatches, the agent(s) that are dispatched, and sometimes a README summary. When such
a rule was independently restated (not centrally referenced) in each relevant location,
subsequent fixes repeatedly patched only the site a review finding literally named,
leaving the same fact stated at a different strength or in stale wording elsewhere in
the same plugin — sometimes in the very same file, sometimes discovered only by a
reviewer's fresh read weeks later.

## Alternatives Considered

### Leave contracts independently restated per file, rely on review to catch drift

- Pros: no upfront refactor cost; each file is self-contained and doesn't require
  cross-referencing to understand.
- Cons: repeatedly, demonstrably fails — drift was caught by review after shipping, not
  before, on at least five separate stories, and "fix the paragraph the finding cited"
  reliably left sibling restatements uncorrected.

### Extract every shared contract into its own dedicated ref file immediately, even for a rule stated in only two places

- Pros: maximal consistency, no restatement possible anywhere.
- Cons: over-applies the pattern — a two-site rule doesn't need a new file; the deciding
  factor should be "how many sites, and how likely to drift," not a blanket rule for
  every shared fact regardless of scope.

## Consequences

- Fixing a shared contract now means fixing it in one place and confirming every pointer
  still resolves — cheaper and less error-prone than repo-wide review-driven drift
  detection.
- Requires discipline at authoring time: when adding a second site that needs the same
  rule, the author must recognize "this already exists elsewhere" and add a pointer
  rather than reaching for a quick independent restatement, which is the natural instinct
  under time pressure.
- After any "fix a stated contradiction" review finding, the correct closing action is a
  repo-wide grep for the concept's other restatements, not just re-verifying the one
  paragraph the finding cited.
- Revisit if a shared contract's pointer-vs-canonical split itself becomes hard to
  navigate (e.g. too many pointers referencing one dense canonical section) — at that
  point splitting the canonical section itself may be warranted.
