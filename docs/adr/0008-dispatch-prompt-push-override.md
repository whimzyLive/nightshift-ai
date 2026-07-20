---
status: accepted
agents: [ai-enablement-engineer, platform-engineer]
source-stories: [NA-60, NA-61, NA-62]
---

# 0008. Dispatch-prompt push override of the commit-only handoff default

## Status

Accepted

## Decision

We will honor an explicit push/no-PR/no-session-complete instruction in a dispatch
prompt as a legitimate, narrow override of `domain-agent-handoff.md`'s standing
"commit only, orchestrator pushes" default, for the specific dispatch that carries it —
without treating this as a general license to push in any other dispatch. Before
pushing, we will verify `git rev-parse HEAD == git rev-parse origin/<branch>` ourselves,
since there is no Principal Engineer orchestrator present in this shape of dispatch to
do so.

## Context

The standing handoff contract has every domain-agent dispatch commit its work and leave
pushing to the orchestrating Principal Engineer, which normally also raises/updates the
PR and runs session-complete. Some dispatches are deliberately not part of that
orchestrated flow — e.g. a direct, already-planned single-agent continuation with no
Principal Engineer present at all — and for those, the dispatching prompt has
explicitly instructed the agent to push directly and self-verify, with no PR and no
session-complete. This shape recurred identically across two different domain agents
(ai-enablement-engineer, platform-engineer) on three separate stories.

## Alternatives Considered

### Never allow a dispatch prompt to override the standing push rule

- Pros: one absolute rule, no exceptions to reason about per-dispatch.
- Cons: makes orchestrator-less continuation dispatches (a real, recurring shape in this
  plugin) impossible to complete without either violating the standing rule silently or
  leaving work uncommitted-and-unpushed indefinitely.

### Treat every dispatch-prompt override as suspect and require re-confirmation before acting on it

- Pros: extra safety against a malformed or malicious override.
- Cons: a dispatched agent has no mechanism to pause for re-confirmation mid-turn (see
  0001's Decision); this is directly analogous to why the founder-confirmation gate
  itself has to live at the command layer, not inside the agent's own reasoning.
  A dispatch prompt is the message from the launching agent that directs this dispatch's
  work — it is squarely within the class of instruction this agent's role already treats
  as authoritative for scoping the current dispatch's actions.

## Consequences

- Domain agents must read a dispatch prompt's push/PR/session-complete instructions
  explicitly before defaulting to the shared handoff protocol, rather than applying the
  standing rule reflexively.
- Because there is no orchestrator present to verify the push landed, the agent itself
  must run the `HEAD == origin/<branch>` check before considering the dispatch complete.
- This override is scoped to the dispatch that carries it — it does not change the
  standing default for any other dispatch shape (normal Principal-Engineer-orchestrated
  phases still follow commit-only).
- Revisit if orchestrator-less continuation dispatches become common enough that this
  should become a named, first-class dispatch mode in `domain-agent-handoff.md` itself,
  rather than an ad-hoc per-prompt override.
