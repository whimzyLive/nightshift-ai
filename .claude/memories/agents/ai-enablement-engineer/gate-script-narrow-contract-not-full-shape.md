---
id: gate-script-narrow-contract-not-full-shape
agent: [ai-enablement-engineer]
trigger: [check-agent-skill-preloads.sh contract, restructuring required-skills prose, worried about tripping a gate]
rule: Read a gate script's actual implementation before assuming a prose restructuring needs a "skip and report not-applied" fallback.
evidence: [NA-52]
uses: 0
status: active
---

## Why

`check-agent-skill-preloads.sh` doesn't enforce the shape of an agent's "Required skills" prose —
this means merging several restatements of a shared skill list into one canonical statement is
always safe from the gate's perspective; the actual risk is losing information (e.g. quietly
dropping the distinction between an unconditional and a conditionally-loaded skill), not tripping
the gate.
