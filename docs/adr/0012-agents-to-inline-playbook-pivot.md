---
status: accepted
agents: []
source-stories: [NA-75]
trigger: [subagent nesting limit, orchestration agent dispatch, inline playbook execution, dead agent definition removal, contract drift]
---

# 0012. Orchestration roles are inline playbooks, never dispatchable agents

## Status

Accepted

## Decision

We will implement the plugin's two orchestration roles — principal-engineer and qa-engineer — as
inline playbooks (`refs/principal-engineer-playbook.md`, `refs/qa-engineer-playbook.md`) executed
directly within the invoking command's own session (`/impl`, `/auto`, `/review`), never as
dispatchable subagents. Any agent-definition file that exists only to dispatch other agents is
removed from `plugins/sdlc/agents/` rather than kept alongside its playbook ref.

## Context

The plugin originally modeled every SDLC role uniformly: a Markdown agent definition under
`plugins/sdlc/agents/`, dispatched via the Agent tool, including the two orchestration roles —
principal-engineer (dispatches domain agents in a fixed dependency order) and qa-engineer (runs
the review → fix → learn loop, itself dispatching domain agents to apply fixes). Claude Code
permits only one level of subagent nesting: a dispatched subagent cannot itself invoke the Agent
tool to dispatch further subagents. An orchestrator whose whole job is dispatching other agents is
therefore fundamentally undispatchable as a subagent — it can only run in a session that has not
itself already been dispatched.

The commands that needed this orchestration worked around the limit by inlining the orchestration
logic directly into their own session instead of delegating to a dispatched principal-engineer or
qa-engineer agent. That pivot happened without formally retiring the two original agent-definition
files: `plugins/sdlc/agents/principal-engineer.md` and `plugins/sdlc/agents/qa-engineer.md`
continued to exist as tombstones alongside the now-canonical playbook refs, each restating enough
of the same contract (tools, control flow, dispatch order) to drift out of sync with what the
playbook refs — the artifacts commands actually execute — say. NA-73 found this duplication had
already produced a Critical drift finding. The docs-reference pipeline compounded the problem: it
generated public `docs/reference/agents/` pages for both dead defs, presenting the two roles to
consumers as dispatchable agents when nothing in the plugin ever dispatches them.

## Alternatives Considered

### Keep the agent defs as documentation-only stubs pointing at the playbook refs

- Pros: preserves a discoverable "full role catalog" entry point without touching the docs
  pipeline's index generation.
- Cons: this is the shape that caused NA-73's drift in the first place — a stub still has to
  restate enough of the contract (tools, triggers, control flow) to be useful, and that restated
  fragment is exactly what diverges over time. A stub with zero restated contract is
  indistinguishable from deleting the file, so this doesn't actually solve the problem.

### Lift the one-level subagent-nesting limit

- Pros: would let principal-engineer/qa-engineer keep working as dispatchable agents unchanged,
  preserving symmetry with the domain-agent roster.
- Cons: not something this plugin controls — it is a Claude Code platform constraint on the Agent
  tool, not a plugin-configurable behavior.

### A distinct "meta-agent" invocation primitive for orchestration roles

- Pros: could give orchestration a first-class construct distinct from both a plain dispatchable
  agent and command-inlined logic.
- Cons: no such primitive exists in the harness today; building one is a disproportionate
  investment against a problem that "run the same instructions inline" already solves, and has
  been solving since the earlier undocumented pivot.

### Inline playbooks, remove the dead agent defs (chosen)

- Pros: a single canonical statement of each orchestration role's contract
  (`refs/principal-engineer-playbook.md`, `refs/qa-engineer-playbook.md`), executed directly by
  the commands that need it, with no duplicate agent-def copy left to drift; the
  `plugins/sdlc/agents/` roster now lists only agents that are genuinely dispatchable, matching
  what the harness — and this plugin's own dispatch pattern — actually supports; removes a class
  of "phantom" agent a consumer might read about and expect to dispatch directly.
- Cons: a consumer-facing removal of two previously-documented agent types, which must be called
  out in the CHANGELOG; loses whatever discoverability came from browsing the full role roster in
  one directory, since orchestration-role documentation now lives under `refs/` instead of
  `agents/`.

## Consequences

- Single-statement contracts for principal-engineer's and qa-engineer's orchestration behavior
  (`refs/principal-engineer-playbook.md`, `refs/qa-engineer-playbook.md`), with no duplicate
  agent-def copy left to drift out of sync — this closes the class of Critical finding NA-73
  surfaced.
- `plugins/sdlc/agents/` now lists only agents that are genuinely dispatchable via the Agent tool
  (the domain agents); orchestration roles are documented and executed as inline playbooks
  instead.
- Consumer-facing removal of the principal-engineer and qa-engineer agent types — called out in
  CHANGELOG as a removal for any consumer that referenced them directly (e.g. attempted to
  dispatch either by name).
- The two orchestration roles persist in the memory protocol despite no longer being agent-def
  files: the memory-collection permissions table, the qa-engineer rule directory convention, and
  the principal-engineer exclusion carve-out all remain valid — this decision changes where the
  dispatch contract lives, not the identity of either role in the memory/permissions model.
- Negative: the public docs surface loses two previously-generated agent-reference pages
  (`docs/reference/agents/principal-engineer.md`, `docs/reference/agents/qa-engineer.md`); anyone
  who had bookmarked those URLs gets a 404 until they're redirected to the playbook refs instead.
- Revisit this decision if: Claude Code's Agent tool lifts the one-level subagent-nesting limit —
  at that point, re-evaluate whether reinstating principal-engineer/qa-engineer as dispatchable
  agents is worth reintroducing the contract-duplication risk this decision exists to avoid.
