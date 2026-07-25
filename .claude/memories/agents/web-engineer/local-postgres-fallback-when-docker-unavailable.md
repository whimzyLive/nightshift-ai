---
id: local-postgres-fallback-when-docker-unavailable
agent: [web-engineer]
trigger: [docker info hangs, no reachable Postgres in sandbox, homebrew postgresql fallback]
rule: When Docker is unreachable in the sandbox (hangs/times out even with elevated permissions) but a live Postgres is needed for verification (migrations, seed idempotency), fall back to Homebrew's.
evidence: [NA-31]
uses: 0
status: active
---
