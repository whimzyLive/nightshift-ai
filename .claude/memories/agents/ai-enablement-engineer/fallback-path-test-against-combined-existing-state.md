---
id: fallback-path-test-against-combined-existing-state
agent: [ai-enablement-engineer]
trigger: [legacy fallback path, degraded-mode verification, collect-memory.sh legacy branch]
rule: When verifying a "keep working, degraded" fallback path, test it against a fixture that combines the OLD state with whatever the feature already populates elsewhere in the real system.
evidence: [NA-73]
uses: 0
status: active
---

## Why

`collect-memory.sh`'s legacy branch had an early `exit 0` right after the `LEGACY` banner, so a repo
with BOTH a flat diary (unmigrated) AND real ADRs under `docs/adr/` never reached the ADR scan — an
agent in legacy mode lost ADR visibility v1 never had this gap for. The verification task ran the
script against this exact repo but only checked for the `LEGACY` banner + exit code, never diffed
the full output against what the ADR scan alone would have produced, and the authored fixtures never
combined a legacy flat diary WITH populated `docs/adr/`.
