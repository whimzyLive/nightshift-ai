---
id: grouping-contract-needs-explicit-fallback-bucket
agent: [ai-enablement-engineer]
trigger: [per-agent index generation, one-section-per-named-agent grouping, ADR with agents: [] has nowhere to go]
rule: "Any classification/grouping rule in a skill or ref needs an explicit branch for the empty/omitted case, or a record with no matching key has nowhere to go — add a named fallback bucket."
evidence: [NA-44]
uses: 0
status: active
---
