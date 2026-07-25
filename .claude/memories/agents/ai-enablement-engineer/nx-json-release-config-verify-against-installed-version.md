---
id: nx-json-release-config-verify-against-installed-version
agent: [ai-enablement-engineer]
trigger: [nx.json release block, releaseTagPattern, spec's literal Nx config JSON]
rule: When a spec/plan gives literal `nx.json` release config JSON, don't trust it byte-for-byte against a fast-moving API surface.
evidence: [NA-63]
uses: 0
status: active
---

## Why

The spec's verbatim `nx.json` used `releaseTagPattern` as a flat top-level key — the pre-Nx-22 shape,
a hard error (not a deprecation warning) in the installed nx@23.0.1. Nx 22 moved it into a nested
`releaseTag: { pattern, ... }` object and Nx 23 removed the flat keys. Fixed by using the nested
shape; dry-run output confirmed the functionally identical outcome. Separately: a first
(pre-baseline-tag) `nx release --dry-run --first-release` computes the bump from the project's
ENTIRE git history, not a small illustrative diff — a dramatic first-run bump/CHANGELOG preview is
expected pre-backfill behavior, not a bug.
