---
id: verify-tombstone-content-parity-before-deletion
agent: [ai-enablement-engineer]
trigger: [deleting agent-def file, tombstone agent file, retiring undispatchable agent]
rule: When retiring an agent-def file a playbook supersedes, diff its protocol steps (e.g. a collect-memory.sh call) against the playbook first — content absent there was already dead, not new regression.
evidence: [NA-75]
uses: 0
status: active
---

## Why

Deleting `plugins/sdlc/agents/qa-engineer.md` (NA-75) surfaced that its "Collect applicable
memory" step (`collect-memory.sh qa-engineer`) was never duplicated in
`refs/qa-engineer-playbook.md` — the file's own header already named the playbook as source of
truth, so this content had been unexecuted dead prose since the playbook took over, not something
this deletion newly broke. Checking playbook coverage before deleting confirms which is true
(safe pure-duplicate vs. a real content gap worth flagging for a follow-up story) instead of
assuming the "tombstone" framing applies uniformly to every section of the doomed file.
