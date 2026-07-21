---
title: What is the sdlc plugin
description: A repo-agnostic SDLC automation layer for Claude Code that drives Jira stories through spec, plan, implementation, and review
related-adrs: [docs/adr/0001-two-phase-dispatch-founder-confirmation-gate.md]
---

# What is the sdlc plugin

The sdlc plugin is a repo-agnostic SDLC automation layer for Claude Code. It takes a Jira
story and drives it along the software lifecycle — refine, spec, plan, implement, review —
without hard-coding anything about the codebase it runs against. The same plugin installs into
a web app, a mobile app, or an infrastructure repo; what changes per repo is a small config
file, not the plugin. This page explains why it is built the way it is and how its parts fit
together. For the steps to actually run it, follow the tutorial and how-to guides linked at the
end.

## Why a plugin, and why repo-agnostic

The lifecycle a story travels — turn intent into a spec, turn a spec into a plan, turn a plan
into code, review the code — is the same regardless of stack. The details that differ (which
framework, which test command, where the mobile workspace lives, what the base branch is) are
data, not logic. The plugin keeps that separation strict: the workflow logic ships in the
plugin, and every repo-specific fact is resolved at runtime from the consumer repo's
`.claude/project/project-context.md`, a file the plugin's SessionStart hook auto-loads each
session. Nothing about a particular codebase is baked into an agent or command. That is what
lets one plugin serve every repo, and it is why onboarding a new repo is a config exercise
(`/sdlc:init`) rather than a fork.

A second consequence of running inside Claude Code as subagents: `${CLAUDE_PLUGIN_ROOT}` is
available to hooks and slash commands but not injected into subagents, yet the domain agents
must read bundled refs and run bundled scripts. The plugin resolves this by having the
SessionStart hook write the absolute plugin root to `.claude/.sdlc-plugin-root` in the consumer
repo each session; every agent reads that one-line marker and substitutes it. The file is a
regenerated per-session cache, so it belongs in the repo's `.gitignore`. This is plumbing, but
it is the plumbing that makes "repo-agnostic plugin whose agents still find their own bundled
assets" work at all.

## The domain-agent model

The plugin does not implement the lifecycle as one monolithic prompt. It models the roles a
real software team would fill, and gives each role its own agent with its own scope. The
lifecycle is a relay between these agents rather than a single actor wearing every hat.

Roughly in order of when they act:

- **product-manager** turns a vague idea into a product-language feature with acceptance
  criteria — no technical detail.
- **scrum-master** decomposes an approved feature into stories, and triages or refines rough
  stories into well-formed ones.
- **solutions-architect** converts an approved story into a technical design spec: data model,
  API surface, permissions, UI and sync behaviour.
- **tech-lead** converts that spec into an implementation plan with tasks tagged by agent and
  ordered by dependency.
- **principal-engineer** executes the plan by dispatching the engineering domain agents in a
  strict dependency order: **database-administrator** → **platform-engineer** →
  **sync-engineer** (when the change touches the sync layer) → **web-engineer** →
  **mobile-engineer**. The **ai-enablement-engineer** is dependency-free and may run at any
  point in that order when a story touches AI-config paths.
- **qa-engineer** owns the post-implementation review loop — review, fix, re-review until the
  branch is clean, secure, and every acceptance criterion is evidenced.
- **knowledge-engineer** curates Architecture Decision Records and runs the docs pipeline.

Two design choices in this roster are worth drawing out. First, the engineering phases run
**sequentially, one domain agent at a time** — the database schema settles before the backend
builds against it, the backend settles before the sync layer and frontend consume it. This is
not timidity about parallelism; it is that these phases have genuine data dependencies, and
running them in order avoids a class of merge and rework churn that a naive fan-out would
create. Second, each agent's scope is narrow and its stack is project-defined. A web-engineer
owns the web frontend and reads its stack from project-context; it does not know or care what
framework the mobile app uses. Narrow scope plus project-defined stack is the same
repo-agnostic principle applied at the agent level.

Two agents earn a longer note because their ownership is deliberately conditional:

- **ai-enablement-engineer** owns the repo's AI-configuration surface — `CLAUDE.md`,
  `AGENT(S).md`, `.agents/**`, `.claude/**`, and (where the repo opts in) `plugins/**` and
  `skills/**`. That ownership is granted per-repo at init by opt-in, not by default; a repo
  that does not opt in leaves the agent inactive with no effect. It prints its resolved
  write-scope at the start of a run and refuses any write outside it.
- **knowledge-engineer** owns ADR curation under `docs/adr/**` and regenerates
  `docs/adr/index.md` deterministically from ADR frontmatter, so domain agents read a
  generated index instead of re-deriving conventions.

## Complexity triage: not every story needs the whole pipeline

Running spec, plan, review-gate, and implementation for a one-line copy fix would be pure
ceremony. The plugin avoids that by triaging every story on complexity before routing it, using
one shared triage definition (`plugins/sdlc/refs/triage.md`) applied inline so that `/auto`,
`/impl`, and `/triage` all decide the same way.

The decision is a story-points threshold. Stories at or below the configurable lightweight
threshold (default 3 points, inclusive) are classified **lightweight** and go straight to
implementation, with tasks derived inline from the ticket — no spec, no plan. Larger stories
are classified **full** and run the whole flow: spec, a review gate on the spec, then plan and
implementation. Bugs are a special case: they force a lightweight classification and route
through the systematic-debugging path regardless of points.

The reasoning is proportionality. The spec-and-plan phases exist to de-risk changes big enough
that getting the design wrong is expensive; below the threshold, that risk does not justify the
overhead, and the ticket itself carries enough to implement against. The threshold is per-repo
config, not a constant, because "big enough to need a spec" is a judgement that varies by team
and codebase. Triage reads existing story points and never sets them — an unpointed story is a
signal to stop and ask a human to point it, not to guess a route.

## Two-phase dispatch and the founder-confirmation gate

The plugin automates the lifecycle but does not remove the human from the loop at the points
that matter. It places explicit confirmation gates at irreversible or judgement-heavy
boundaries — approving a spec before planning, confirming an ADR before it is written and
committed, confirming a proposed AI-config fix before it is applied.

This creates a structural problem. A gate needs to pause and wait for interactive human input,
but a dispatched subagent cannot pause for that input — it runs to completion and returns. The
plugin resolves this with a **two-phase dispatch** pattern, and this is a documented
architectural decision rather than an incidental convention. Phase one runs a subagent that
does all the work up to the decision point and returns its proposal **without writing anything**
— a drafted ADR, a proposed diff, a spec ready for review. The gate itself lives at the command
layer, which can pause; it presents the proposal and waits for explicit confirmation. Phase two
then runs only the confirmed items, doing the writes and raising the PR.

The value of the split is that automation does the laborious drafting while the human retains
the go/no-go decision, and nothing irreversible happens on the far side of a gate until a person
has said yes. It is the same shape everywhere a gate appears, which is what makes the behaviour
predictable: work is always reviewable as a diff or a PR before it lands, and the default is to
refuse and surface rather than to auto-apply.

## Dependencies and how they connect

The plugin declares two other plugins as cross-marketplace dependencies, both auto-installed
with it:

- **superpowers** provides the reusable skills the domain agents invoke — writing-plans,
  executing-plans, subagent-driven-development, test-driven-development,
  verification-before-completion, and the requesting/receiving-code-review skills the QA loop
  runs against. The plugin leans on these rather than reimplementing disciplined
  plan-execution and review inside its own agents.
- **claude-mem** provides the persistent cross-session observation store that the
  knowledge-engineer's `/sdlc:docs distill` mode mines for promotable ADR candidates. It is
  needed only by that mode; if its tools are unavailable at runtime, distill halts with a clear
  message and the rest of the plugin is unaffected.

Two CLIs are required but installed manually, not as plugins: `acli` for Jira and `gh` for
GitHub. They are the plugin's hands on the two external systems the lifecycle touches — the
issue tracker it reads stories from and comments gates back to, and the forge it raises PRs
against.

## Related decisions

- [docs/adr/0001-two-phase-dispatch-founder-confirmation-gate.md](docs/adr/0001-two-phase-dispatch-founder-confirmation-gate.md)
  records the two-phase dispatch pattern for founder-confirmation gates described above — why a
  gate lives at the command layer and a subagent drafts without writing. Refer to it for the
  decision's full context and consequences rather than treating this page as the source of
  truth for that reasoning.

## Where to go next

- To run the pipeline end to end for the first time, follow the tutorial:
  [docs/tutorials/getting-started-with-sdlc.md](docs/tutorials/getting-started-with-sdlc.md).
- To drive a specific existing story through the pipeline, follow the how-to guide:
  [docs/how-to/run-the-sdlc-pipeline-on-a-story.md](docs/how-to/run-the-sdlc-pipeline-on-a-story.md).
