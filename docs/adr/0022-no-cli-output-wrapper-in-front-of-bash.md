---
status: accepted
agents: [ai-enablement-engineer, platform-engineer]
source-stories: []
---

# 0022. No CLI output wrapper in front of Bash tool calls

## Status

Accepted — supersedes [ADR-0015](0015-raw-binary-fallback-on-wrapped-cli-mismatch.md).

## Decision

We will run Bash tool calls against the raw binaries. No token-compressing wrapper (`rtk` or any
successor) is installed as a `PreToolUse` hook, no project hook rewrites command lines, and the
`rtk-coverage` instrument that scored that wrapper is removed with it.

## Context

The wrapper was added when models tolerated less context. Measured on 83 kova sessions
(2026-11-05 to 2026-11-13, 14,980 turns) and one ground-truth day (2026-11-11):

| Measure                                                 | Value                                    |
| ------------------------------------------------------- | ---------------------------------------- |
| Bash output reaching any context that day, post-wrapper | 452k tokens                              |
| Wrapper's own claimed saving that day                   | 23.2M tokens (85× the transcript figure) |
| Real saving at Opus 5.5 rates                           | ≈ $4–5 on a ≈ $197 day (~2%)             |
| Bash calls starting with `cd` (hook never fired)        | 1,036 of 4,693                           |
| Explicit `rtk proxy` escapes by the model               | 311                                      |

The harness already spills any Bash output past its limit to a file, so the wrapper's largest
claimed wins were on bytes that never would have entered context. Its costs were real: wrapped
exit codes disagreeing with printed output (ADR-0015), compacted diffs returning false-clean scans,
a per-call hook spawn, a line-1-only rewrite contract that needed its own CI-wired instrument.

## Alternatives Considered

### Keep the wrapper and fix its gaps

- Pros: lint and test output compression is genuine on noisy runs; tooling already exists.
- Cons: ~2% ceiling on the bill; every gap fixed so far produced another contract to maintain
  (line-scan hook, coverage instrument, ADR-0015 fallback rule).

### Replace with a proxy-level compressor (e.g. headroom)

- Pros: sees Read, Grep, and MCP output, not just Bash; cache-safe by design; honest per-turn
  billed stats.
- Cons: same small denominator in pipeline runs; a daemon in every request path; subscription
  auth and deferred tool loading behind a custom base URL unverified.

### No wrapper (chosen)

- Pros: nothing to maintain, no exit-code mismatch class, no false-clean scans, one fewer process
  per tool call.
- Cons: a noisy failing test run returns up to the native cap of raw output and may cost one extra
  turn to grep the spilled file.

## Consequences

- ADR-0015's fallback rule has nothing to fall back from and is superseded, not deleted.
- `.claude/hooks/rtk-line-scan.sh`, its tests, `tools/sdlc-analyser/rtk-coverage.py`, and their CI
  steps are removed. NA-89's Gate 1 no longer exists as a running check.
- Noisy command output is bounded by the harness cap only. Agents that need a summary ask for one
  with `| tail`, `| grep`, or a script, as they would in any shell.
- Output-side efficiency (what the model writes) is a separate concern and is not decided here.
- Revisit this decision if: per-run Bash output rises above ~10% of cache-read volume in the
  pipeline, or a compressor can prove its saving from billed usage rather than its own counter.
