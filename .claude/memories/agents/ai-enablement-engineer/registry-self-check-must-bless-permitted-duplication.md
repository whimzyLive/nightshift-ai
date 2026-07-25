---
id: registry-self-check-must-bless-permitted-duplication
agent: [ai-enablement-engineer]
trigger: [single source of truth cell still permits an in-file mirror, schema-table example duplication]
rule: A "single source of truth cell, others reference it" fix for a duplicated literal string needs the registry's own self-check section to explicitly bless the in-file duplication it still permits.
evidence: [NA-52]
uses: 0
status: active
---

## Why

Added an explicit self-check bullet naming both in-file locations as the sanctioned mirror and every
other file as reference-only — the same "precedence rule stated in the guard itself, not just in
prose above it" pattern, applied to a duplication guard instead of a gating guard.
