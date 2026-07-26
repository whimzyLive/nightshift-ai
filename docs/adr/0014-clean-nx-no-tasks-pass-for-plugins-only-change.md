---
status: accepted
agents: [ai-enablement-engineer, platform-engineer]
source-stories: [NA-52, NA-54, NA-55, NA-57, NA-60, NA-61, NA-62, NA-63, NA-65, NA-68]
trigger: [nx affected no tasks, plugins sdlc only change, nx format check clean, plugins gtm only change]
---

# 0014. Clean Nx "no tasks were run" result is accepted as a pass for plugins-only changes

## Status

Accepted

## Decision

We will treat `pnpm nx affected -t test --base=remotes/origin/develop` / `pnpm nx format:check`
reporting "No tasks were run" (or otherwise exiting clean) for a change scoped entirely to
`plugins/sdlc/**` or `plugins/gtm/**` as a valid, sufficient pass condition — not a sign of a
broken, misconfigured, or skipped quality gate.

## Context

No Nx project in this workspace's project graph owns `plugins/sdlc/**` or `plugins/gtm/**` —
those paths are documentation/instructions content (agent, command, and skill markdown), not
source consumed by any Nx target. Confirmed repeatedly, across ten separate plugins-only stories,
that an affected-scoped run against a plugins-only diff reports no tasks / a clean result. Absent
a documented convention, this clean-but-empty result is easy to mistake for the gate having been
skipped, misconfigured, or silently failing, rather than functioning exactly as the project graph
dictates.

## Alternatives Considered

### Treat "no tasks were run" as suspicious and investigate every time

- Pros: would catch a genuine Nx misconfiguration if the project graph is ever wrong.
- Cons: wastes real time on every single plugins-only story re-litigating an already-confirmed
  benign result, with no new signal produced by the re-investigation.

### Add a synthetic Nx project/target for `plugins/**` purely to give the affected graph something to run

- Pros: removes the "no tasks" ambiguity entirely.
- Cons: no real build/test/lint work exists to run against markdown-only content; this would be a
  synthetic no-op target that exists purely for reassurance, adding maintenance surface for zero
  functional gain.

### Document and accept "no tasks" as a valid pass (chosen)

- Pros: matches the actual shape of the project graph, adds no new tooling.
- Cons: depends on the convention being known to whoever runs the gate, rather than being
  self-evident from the tool's raw output alone — hence recording it here.

## Consequences

- Removes needless investigation time on every plugins-only-change story going forward.
- Depends on this convention being known/discoverable rather than left tribal — this record is
  that discoverable form.
- A change that touches both a plugins-only path and a path some Nx project DOES own will still
  run tasks for the owned part as normal; this convention narrowly covers the plugins-only-diff
  case, not mixed diffs.
- Revisit if an Nx project is ever added that legitimately owns any part of `plugins/sdlc/**` or
  `plugins/gtm/**`.
