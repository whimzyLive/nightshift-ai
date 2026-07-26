---
status: accepted
agents: [ai-enablement-engineer, platform-engineer]
source-stories: [NA-57, NA-62, NA-63]
trigger: [rtk proxy mismatch, wrapped command exit code disagreement, tsc prettier false success]
---

# 0015. Raw-binary fallback on wrapped-CLI output/exit-code mismatch

## Status

Accepted

## Decision

We will, whenever a wrapped command's printed output and exit code visibly disagree (e.g. under
the user's `rtk` proxy hook), reach immediately for the raw binary or `rtk proxy <cmd>`, rather
than spending time debugging the mismatch itself.

## Context

`pnpm exec tsc ...` printed "TypeScript: No errors found" but still exited 1; `pnpm exec prettier
--check <file>` printed a misleadingly generic "all files formatted correctly" while still exiting
1 (or exited 0 while a real issue existed). Both are wrapper artifacts of the proxy layer sitting
in front of the real binary, not signals about the file or build state itself — confirmed across
three stories by re-running the raw binary and getting a trustworthy, matching exit code/output.

## Alternatives Considered

### Debug the wrapper/hook itself each time the mismatch appears

- Pros: might eventually surface and fix a root cause in the wrapper.
- Cons: expensive every time it recurs, has not converged on a durable upstream fix across three
  separate stories, and blocks the actual task at hand while it's being investigated.

### Always trust the printed output over the exit code (or vice versa)

- Pros: fast, no extra step.
- Cons: exactly backwards in an unpredictable way — which signal is the unreliable one varies by
  case (sometimes the text lies, sometimes the code does), so picking one to always trust risks
  silently missing a real failure.

### Reach for the raw binary or `rtk proxy <cmd>` immediately on mismatch (chosen)

- Pros: cheap, fast, and resolves the ambiguity by producing a trustworthy result directly instead
  of reasoning about which signal to trust.
- Cons: requires recognizing the output/exit-code-disagreement pattern in the first place, and
  knowing `rtk proxy` exists as an escape hatch.

## Consequences

- Saves debugging time whenever this exact wrapper-artifact pattern recurs.
- Requires whoever hits it to recognize "output and exit code disagree" as the trigger, rather than
  attempting to diagnose the wrapper itself.
- Does not fix the underlying wrapper mismatch — this is a practical workaround, not a wrapper
  bugfix; the wrapper's real bug remains unaddressed.
- Revisit if the user's `rtk` proxy hook is fixed upstream to eliminate the output/exit-code
  disagreement.
