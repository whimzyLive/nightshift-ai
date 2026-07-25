---
id: agent-reference-deletion-drops-page-and-llms-entry
agent: [knowledge-engineer]
trigger: [deleting an agent-def file, sourceless reference page, agent-reference row on deletion]
rule: When `plugins/sdlc/agents/<name>.md` is deleted, delete its now-sourceless `docs/reference/agents/<name>.md` page outright (never blank/stub it) and remove its single-line entry from `llms.txt`'.
evidence: [NA-75]
uses: 0
status: active
---

## Why

Deterministic regen has nothing to regenerate the page from once its source is gone. Verify
correctness by counting: the number of files left in `docs/reference/agents/` after deletion must
exactly match the number of `docs/reference/agents/*.md` line-entries left in `llms.txt`.
