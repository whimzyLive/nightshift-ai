---
title: 'Hooks reference'
description: 'The full hook contract for this repo: no repo-level hooks are configured in .claude/settings.json, but the sdlc and gtm plugins each register SessionStart and SessionEnd hooks that run regardless.'
---

# Hooks reference

The full hook contract for this repo: no repo-level hooks are configured in `.claude/settings.json`,
but the sdlc and gtm plugins each register SessionStart and SessionEnd hooks that run regardless.
A repo whose `.claude/settings*.json` carries zero hooks does not mean "no hooks defined": with one
or more plugins installed that register hooks, a real hook contract still exists, and it is
documented below.

---

## Repo-level hooks (`.claude/settings.json`)

`.claude/settings.json` carries `enabledPlugins`, `extraKnownMarketplaces`, and `sandbox` blocks,
but **no `hooks` block** — zero repo-level hooks are configured directly in this file.

**Source:** `.claude/settings.json`

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
