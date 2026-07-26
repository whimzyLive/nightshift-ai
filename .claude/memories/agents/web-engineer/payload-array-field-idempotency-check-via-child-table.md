---
id: payload-array-field-idempotency-check-via-child-table
agent: [web-engineer]
trigger: [Payload seed idempotency verification, array field on a global, count and order-check]
rule: Verify a Payload seed's idempotency (a second run never duplicates) by running it twice, asserting row/child counts via a direct `psql` query both times, and confirming `updatedAt`-affecting fie.
evidence: [NA-31]
uses: 0
status: active
---
