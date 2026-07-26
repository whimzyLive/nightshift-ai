---
status: accepted
agents: [ai-enablement-engineer, platform-engineer, knowledge-engineer, qa-engineer]
source-stories: [NA-12, NA-25, NA-26, NA-27, NA-43, NA-52, NA-54, NA-57, NA-60, NA-65, NA-73, NA-75]
trigger: [renaming a shared contract, ownership reassignment, renumbering a cross-referenced list, shared contract literal grep]
---

# 0013. Whole-tree literal grep as the closing step after any shared-contract change

## Status

Accepted

## Decision

We will, after any shared-contract change (rename, renumber, ownership reassignment, or deletion
of a referenced file) affecting `plugins/sdlc/**` or `plugins/gtm/**`, run a whole-repository grep
for the exact old literal string — not merely a structural/regex pattern — as the mandatory closing
verification step before considering the change complete.

## Context

This exact failure shape recurred across twelve stories: a review names only 2-3 of N occurrences
of a stale enumeration, count, or reference; independently-authored restatements (agent-file prose
vs. playbook, sibling ref files, a command's own self-referential example) drift out of sync
because nothing greps or lints for them staying aligned. ADR-0004 already establishes writing a
shared contract once, with pointers, as the authoring-time discipline — but that convention doesn't
retroactively catch pre-existing independent copies predating a dedup pass, nor a fresh restatement
accidentally introduced instead of a pointer during a partial fix. A grep scoped to one named file
is not "the whole tree" — independent same-content copies (not `${CLAUDE_PLUGIN_ROOT}` includes) are
exactly what makes partial fixes drift.

## Alternatives Considered

### Trust the review process alone to catch drift

- Pros: no additional mechanical step; matches how this worked before the pattern was recognized.
- Cons: repeatedly, demonstrably insufficient — confirmed missing occurrences across many stories,
  caught by a later reviewer's fresh read rather than the fix itself.

### Structural/regex search for the pattern, rather than the exact literal

- Pros: also catches paraphrased restatements the literal grep would miss.
- Cons: much noisier — high false-positive rate makes results harder to triage, and in practice
  the recurring failure was exact-copy drift, not paraphrase drift.

### Rely on ADR-0004's "single canonical statement" convention alone

- Pros: prevents new restatements from being introduced going forward.
- Cons: doesn't fix restatements that already existed before a dedup pass, and doesn't guard
  against an editor accidentally reaching for a fresh restatement instead of a pointer at edit
  time — a closing grep still catches that lapse even when the authoring discipline is followed
  imperfectly.

## Consequences

- Adds one cheap, mechanical step (a full-tree literal grep) to the end of every rename/renumber/
  reassign/delete task in `plugins/sdlc/**`/`plugins/gtm/**` — must not be skipped.
- Complements, not replaces, ADR-0004: 0004 is the authoring-time discipline; this is the
  verification-time backstop that catches both cross-file copies and same-file restatements a
  structural search would miss.
- A grep scoped to a single named file provides no signal here — it must be whole-tree.
- Revisit if CI ever gains an automated lint check for shared-contract restatement drift, making
  the manual grep redundant.
