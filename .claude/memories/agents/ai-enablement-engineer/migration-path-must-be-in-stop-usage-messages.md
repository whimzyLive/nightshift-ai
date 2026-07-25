---
id: migration-path-must-be-in-stop-usage-messages
agent: [ai-enablement-engineer]
trigger: [command removal migration path, deliberately-excluded special route, seed adr usage string]
rule: A command removal's migration path is only clean if the successor surface is discoverable from the STOP/usage messages a confused caller actually hits.
evidence: [NA-57]
uses: 0
status: active
---

## Why

`seed adr` was structurally correct (special route, live, all guards relocated) but invisible at the
two places someone migrating off deleted `/sdlc:adr` would actually look: the usage string (deliberately
excludes `adr` from `SEED_TYPES`) and the unknown-seed-type STOP message. Fixed by adding
`seed adr "<pattern>"` as its own clause in the usage string and a one-line pointer inside the STOP
message.
