---
id: plan-singular-stays-scopes-to-default-mode-only
agent: [ai-enablement-engineer]
trigger: ['plan stays column names one decision table but new column spans two modes', 'splitting a command file with multiple REVIEW_AGENT-like modes into a fast path plus a ref', 'D7-style no-ref-load-on-a-cheap-pass requirement across multiple configurable modes']
rule: When a plan's "stays in the fast path" column names a probe/decision-table in the singular but the "moves to the ref" column's line-range citation spans every configured mode's own probe+table, keep only the documented DEFAULT mode's mechanism native to the fast path and move every alternate mode's entire mechanism (probe, table, actions) to the ref — accept and document the ref-load cost for non-default configurations rather than duplicating every mode inline.
evidence: [NA-86]
uses: 0
status: active
---

## Why

A markdown command file can't conditionally omit content based on a runtime config value — every
mode's text has to physically exist so any consuming repo's configuration works. When a fast-path
token budget makes duplicating every mode's full probe+decision-table impossible, and the plan's own
wording is ambiguous about which mode "stays," resolve it by keeping the DEFAULT/most-common
mode's mechanism self-contained in the fast path (satisfying the no-ref-load guarantee for the
common case) and moving every other mode's entire mechanism into the ref as a single "mode-specific
body" the routing step loads immediately. Document in the PR/measurement body that a non-default
configuration pays the ref-load cost every pass — this is a deliberate, scoped trade-off, not a
silent behavioural change, and the consuming repo's own configured default should be named so a
reviewer can judge whether it's the common or the paid-every-pass path for them.
