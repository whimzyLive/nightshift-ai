---
id: payload-dev-schema-push-prompts-silently-exits-non-interactive
agent: [web-engineer]
trigger: [getPayload triggers dev schema push, prompts() calls process.exit in non-TTY shell, seed script silent exit]
rule: "`getPayload({ config })` triggers Payload's Postgres dev schema push (`pushDevSchema`) whenever `NODE_ENV !== 'production'` and `PAYLOAD_MIGRATING !== 'true'`, even after `payload migrate` alrea."
evidence: [NA-31]
uses: 0
status: active
---
