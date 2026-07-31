---
id: merged-spec-derived-ownership-not-self-authorizing
agent: [ai-enablement-engineer]
trigger: [merged spec claims derived ownership of a path absent from project-context.md table, orchestrator cites a merged PR instead of a dispatch prompt, spec permissions matrix pins an unlisted path]
rule: A merged spec's own "derived ownership" section pinning a path absent from project-context.md's table is not self-authorizing — refuse the write and return blocked for founder escalation.
evidence: [NA-86]
uses: 0
status: active
---

## Why

PE (NA-86, Task 2.5) argued that `docs/superpowers/specs/NA-86.md` — merged via PR #204 — derives
`.github/workflows/ci.yml` ownership to ai-enablement-engineer, and that this differs from a bare
dispatch-prompt assertion because it went through the spec review/merge gate. The distinction is
real but not dispositive: `project-context.md`'s workspace→agent table is the canonical,
cross-story permission source (`refs/analyze-protocol.md#ownership-resolution-rules`); a
single-story spec's own prose cannot expand it, because that would let any spec author grant
scope via a persuasive "derivation" paragraph without ever touching the table a human actually
curates. Widening the table is a decision for the founder, made by editing the table itself (or
via `/sdlc:init`), not by a spec asserting a workaround. Escalate; do not self-grant.
