---
id: placeholder-value-defeats-presence-absence-guard
agent: [ai-enablement-engineer]
trigger: ["TODO —" scalar placeholder, guard checks presence not content, unfilled scaffold]
rule: "Whenever a design introduces a placeholder value that is valid-but-meaningless, re-audit every downstream guard that tests presence/absence to also test \"is this the placeholder\"."
evidence: [NA-61]
uses: 0
status: active
---

## Why

A founder-confirm gate checked presence, and a skip-and-surface rule fired on absence — a
`TODO —` value is present, so neither guard caught an unedited scaffold, which is worse than the
pre-existing behavior (a page with no frontmatter at all was loudly skipped). The placeholder was
designed and the guards' rationale re-scoped in the same PR without ever asking "what if seed
confirms the scaffold unedited" — the two tasks were sequenced correctly per the plan but never
cross-examined against each other from the guard's point of view.
