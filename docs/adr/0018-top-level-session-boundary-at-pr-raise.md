---
status: accepted
agents: [ai-enablement-engineer, platform-engineer]
source-stories: [NA-91]
---

# 0018. Top-level session boundary at PR raise

## Status

Accepted.

## Decision

The session-boundary mechanism is **opt-in**, gated by `SDLC_BOUNDARY_ON`. With the flag **unset**
(the default), every session behaves exactly as it does today — the tail loop runs inline and owns
the single release; nothing about this decision is observable. Only once an operator sets
`SDLC_BOUNDARY_ON` does a top-level SDLC session end at the PR-raise boundary under the automation
harness (`SDLC_SESSION_KEY` set): the phase releases immediately after posting its Jira comment, and
prints the full re-invocation line (`<<<SDLC_NEXT_INVOCATION:<NEXT>>>>`) instead of running the
review-fix loop inline. The re-invoked loop runs as a **new** top-level session and releases its own
slot. Interactive sessions (`SDLC_SESSION_KEY` unset) keep the inline tail unconditionally even with
the flag set, and additionally print the re-invocation line. **Enabling `SDLC_BOUNDARY_ON` is a
precondition the harness must satisfy first, not a switch flipped speculatively**: the flag must stay
unset until the harness that will re-invoke the printed line actually reads it.

## Context

The top-level orchestrator session re-bills every resident tool result on every later turn.
Measured over the pinned corpus, **34.6% of top-level tool-result exposure (pooled)** is the
post-PR-raise tail phase re-charging context produced before the PR existed — the review-fix loop
inherits everything the phase before it accumulated, even though nothing resident is still
load-bearing once the phase's work is durable on a branch and its Jira comment is posted.

The Jira story's AC-1 asks for top-level session **context editing**. That surface does not exist in
a form this repo can drive: verified against the local harness build
(`~/.local/share/claude/versions/2.1.220`, read-only string/AST probe), the API's
`context_management.edits` / `clear_tool_uses_20250919` occurs only inside bundled skill
documentation with no call site this repo constructs; the harness's microcompact
(`compact_micro_keep_recent`) fires only from the server-driven `context_hint` reject path with a
hardcoded `keepRecent` and a `tokensSaved < 20000 -> return null` floor, exposed through no setting,
env var, or slash command; and a `PostToolUse` hook's `hookSpecificOutput` accepts
`additionalContext` only — `updatedOutput` / `updatedToolResult` / `toolResultOverride` have zero
occurrences in the build, so a hook can add context but never shrink it. Ending the top-level session
is the only repo-owned action that actually evicts resident tool results, and
`plugins/sdlc/scripts/session-complete.sh` already performs that release and already carries the PR
URL in its completion marker.

## Alternatives Considered

- **Turn-horizon staleness rules** (clear results older than N turns) recover more of the exposure —
  98.7% at H=5, 94.8% at H=20, 87.6% at H=50 — but need exactly the context-editing surface this
  decision rules out as unreachable. Not implementable from a consuming repo today.
- **Extend the `SDLC_SESSION_COMPLETE` marker with a `|NEXT=` field** instead of a separate printed
  line. Rejected: a harness regex matching `PR=(.+)` greedily would swallow an appended field,
  silently corrupting the PR-URL capture. A separate, additive line is backward-compatible by
  construction; the existing marker and its regex are untouched.
- **Spill top-level Bash output to file** (10.7% of top-level exposure) prevents accumulation rather
  than clearing what already accumulated — a different mechanism, proposed as a separate follow-up
  rather than folded into this decision.
- **Ship the boundary ON by default under the harness, with an opt-out revert lever.** Rejected: no
  harness understands `SDLC_NEXT_INVOCATION` at the time this decision ships, so a default-on session
  would raise its PR, print a line nothing reads, release, and never loop, review, or auto-merge it —
  silently, with no error. A default that depends on an operator remembering to opt out is not a safe
  default; opt-in is the only shape where the unmodified path is proven identical to today's.

## Consequences

- One extra cold instruction-floor cache-write per boundary crossed (median first-write ~28,932
  tokens), modelled at **-0.06 pp** against the cache-read-ratio guardrail's 2.64 pp of headroom
  (two boundaries: -0.11 pp). The guardrail floor is 94%; baseline measured 96.64%.
- The automation harness gains a re-invocation obligation **as a precondition for enabling the
  boundary at all, not a follow-up to it**: it must watch for and re-invoke the printed
  `SDLC_NEXT_INVOCATION` line, including its `--phase` flag and any `--on-clean` auto-merge hook,
  neither of which the existing `|PR=` marker can carry. `SDLC_BOUNDARY_ON` stays unset — the safe,
  behaviour-identical default — until that precondition is verified true; setting it against a
  harness that ignores the line would silently stop Full-Auto auto-merge and the per-phase review
  gate from ever firing on the affected PRs.
- The boundary is measurable per session via `tools/sdlc-analyser/context-residency.py`, whose
  `inheritedShare` and `cacheReadRatio` fields are the gates the Gate-3 pilot (the first
  `TRIAGE=full` story run end-to-end through `/sdlc:auto` after this ADR merges and the plugin cache
  is updated) must satisfy before this decision's cut-rate counts toward the epic's AC-1.
- A successor proposing API-level context editing or harness microcompact configuration must first
  show that surface has become reachable from a consuming repo — it was not, at the time of this
  decision.
