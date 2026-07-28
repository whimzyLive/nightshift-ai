---
id: acli-global-active-site-shared-across-accounts
agent: [ai-enablement-engineer]
trigger: [acli jira auth switch, diagnosing a jira permission-shaped error, wiring a new acli call site]
rule: acli's active Jira site is GLOBAL across every authenticated account — a stale one fails a Jira call with a permission-shaped error, not a site-mismatch one; re-verify it before every call.
evidence: [NA-77]
uses: 0
status: active
---

## Why

Confirmed by direct repro: `acli jira auth switch --site A` then a call succeeds; `acli jira auth
switch --site B` then the SAME key on site A now fails "Issue does not exist or you do not have
permission to see it." — indistinguishable from a real permissions problem. The active site has
also been observed reverting mid-session, including between two consecutive acli calls seconds
apart, so a guard checked once at the top of a multi-call flow is not sufficient — it must run
immediately before each individual Jira call, not just once per command/loop.
