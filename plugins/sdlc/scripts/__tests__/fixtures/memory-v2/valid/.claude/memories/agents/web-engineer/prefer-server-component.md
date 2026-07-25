---
id: prefer-server-component
agent: [web-engineer]
trigger: [server component, data fetching]
rule: When fetching data for a page, prefer a Server Component over a client-side fetch.
evidence: [NA-26]
uses: 0
status: active
---

## Why

Keeps the client bundle smaller and avoids a request waterfall.
