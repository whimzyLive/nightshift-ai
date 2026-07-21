---
title: 'Hooks reference'
description: 'The hooks the sdlc and gtm plugins register in a consumer repo: SessionStart and SessionEnd hooks each plugin installs.'
---

# Hooks reference

The hooks the sdlc and gtm plugins register in a consumer repo: SessionStart and SessionEnd hooks each plugin installs.

---

## Plugin-registered hooks

### sdlc plugin

**Source:** `plugins/sdlc/hooks/hooks.json`

| Trigger        | Matcher | Command                                               | Purpose                                                                                                                                           |
| -------------- | ------- | ----------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `SessionStart` | (all)   | `${CLAUDE_PLUGIN_ROOT}/hooks/load-project-context.sh` | Discovers the plugin root, since `${CLAUDE_PLUGIN_ROOT}` is only injected in hook/command context, not into subagents, and loads project context. |
| `SessionEnd`   | (all)   | `${CLAUDE_PLUGIN_ROOT}/scripts/cleanup-tmp.sh`        | Removes the session's own scoped temp dir (`./.tmp/<key>`) so scratch state never survives an errored or interrupted session. Always exits 0.     |
| `SessionEnd`   | (all)   | `${CLAUDE_PLUGIN_ROOT}/scripts/worktree-gc.sh`        | Reclaims worktrees under `.claude/worktrees/` whose checked-out branch is fully merged into `origin/<BASE-BRANCH>`. Always exits 0.               |

### gtm plugin

**Source:** `plugins/gtm/hooks/hooks.json`

| Trigger        | Matcher | Command                                                 | Purpose                                                                                                                                                                      |
| -------------- | ------- | ------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `SessionStart` | (all)   | `${CLAUDE_PLUGIN_ROOT}/hooks/load-marketing-context.sh` | Standalone functional equivalent of the sdlc plugin's project-context loader (no runtime dependency on that package); discovers the plugin root and loads marketing context. |
| `SessionEnd`   | (all)   | `${CLAUDE_PLUGIN_ROOT}/scripts/cleanup-tmp.sh`          | Removes the session's own scoped temp dir (`./.tmp/<key>`) so scratch state never survives an errored or interrupted session. Always exits 0.                                |
