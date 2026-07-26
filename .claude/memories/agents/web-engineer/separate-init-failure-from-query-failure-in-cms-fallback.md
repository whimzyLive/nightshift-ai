---
id: separate-init-failure-from-query-failure-in-cms-fallback
agent: [web-engineer]
trigger: [distinguishing getPayload init failure from query failure, force-dynamic removal, error classifier]
rule: To distinguish "Payload init failure" from "query failure" without message-sniffing, move `const payload = await getPayload({ config })` OUTSIDE the try/catch entirely.
evidence: [NA-71]
uses: 0
status: active
---

## Why

This is DRY and avoids a fragile `/getPayload|PAYLOAD_SECRET|adapter/i` message regex — simpler than
the plan's suggested regex hack and passes the same literal tests either way.
