---
id: sessionend-hook-timeout-field-inert-in-plugin-hooks-json
agent: [ai-enablement-engineer]
trigger: [editing plugins/sdlc/hooks/hooks.json SessionEnd entries, "Hook cancelled" SessionEnd error, adding a timeout field to a SessionEnd hook]
rule: "A `timeout` on a plugin SessionEnd hook is never read for the shutdown abort budget - only settings-level SessionEnd hooks count; fix ships via consumer `.claude/settings.json` env var."
evidence: [a280648]
uses: 0
status: active
---

## Why

The shutdown budget (`getSessionEndHookTimeoutMs`) is computed only from `settings.SessionEnd`
hooks and floors at 1500ms when none declare a `timeout` — a plugin's own `hooks/hooks.json` is
never in that merged set. `worktree-gc.sh` measures ~3.1s, so the floor always aborts it. The real
lever is `CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS` (or a settings-level SessionEnd hook `timeout`)
in the consumer's own `.claude/settings.json` — see `/sdlc:init`'s Step 5 checklist.
