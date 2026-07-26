---
id: idempotency-guard-needs-finding-id-layer-not-just-slug
agent: [ai-enablement-engineer]
trigger: [idempotency guard operates at wrong granularity, group slug vs branch name match, re-grouping heuristic changes shape]
rule: When a review finds "guard operates at the wrong granularity," add a finer-grained layer rather than just changing what the existing layer compares.
evidence: [NA-7]
uses: 0
status: active
---

## Why

A slug-level-only guard silently breaks the instant a re-run's grouping heuristic (fewest-PRs,
corpus-size-dependent) produces a different branch/PR grouping than a prior run — e.g. run 1 merges
everything into one PR, run 2's larger corpus splits per-category, and slug-level matching alone
sees no collision and re-opens PRs for already-covered findings. `gh pr list --search "head:<prefix>"`
(substring/ref match) is the right primitive for a branch-namespace-prefix idempotency probe —
`--head` only does exact-match and can't express a prefix.
