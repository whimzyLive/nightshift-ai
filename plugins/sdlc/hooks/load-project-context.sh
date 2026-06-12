#!/usr/bin/env bash
# SessionStart hook for the sdlc plugin. Two jobs:
#
#   1. PLUGIN ROOT DISCOVERY. ${CLAUDE_PLUGIN_ROOT} is only available in hook/command context —
#      it is NOT injected into subagents. SDLC agents that need to read bundled refs or run
#      bundled scripts therefore cannot resolve it themselves. This hook (which DOES have it)
#      writes the resolved absolute plugin root to a fixed, repo-relative marker file
#      (.claude/.sdlc-plugin-root) that every agent can read from cwd, regardless of dispatch
#      depth. It also states the mapping in additionalContext for the top-level session.
#
#   2. PROJECT CONTEXT. Injects the consumer repo's .claude/project/project-context.md (if any)
#      as additionalContext, so every session starts with the project's SDLC constants.
#
# Inert-safe: in a repo with neither a .claude dir nor project-context, emits nothing, exit 0.
set -euo pipefail

proj="${CLAUDE_PROJECT_DIR:-$PWD}"
plugin_root="${CLAUDE_PLUGIN_ROOT:-}"

# (1) Drop the plugin-root marker (best-effort: needs the var + an existing .claude dir).
if [ -n "$plugin_root" ] && [ -d "$proj/.claude" ]; then
  printf '%s\n' "$plugin_root" > "$proj/.claude/.sdlc-plugin-root" 2>/dev/null || true
fi

# (2) Assemble additionalContext: root mapping (if known) + project-context (if present).
intro=""
if [ -n "$plugin_root" ]; then
  intro="SDLC plugin root (this session): ${plugin_root}
When any SDLC agent, command, or ref instruction references \${CLAUDE_PLUGIN_ROOT}/..., resolve it against that absolute path. A subagent that does not see this note can read the same value from the repo-relative file .claude/.sdlc-plugin-root."
fi

ctx="$proj/.claude/project/project-context.md"
body=""
[ -f "$ctx" ] && body="$(cat "$ctx")"

if [ -z "$intro" ] && [ -z "$body" ]; then
  exit 0
fi

if [ -n "$intro" ] && [ -n "$body" ]; then
  combined="${intro}

---

${body}"
elif [ -n "$intro" ]; then
  combined="$intro"
else
  combined="$body"
fi

# Emit as additionalContext (JSON-safe via python3, jq fallback).
if command -v python3 >/dev/null 2>&1; then
  printf '%s' "$combined" | python3 -c 'import json,sys; print(json.dumps({"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":sys.stdin.read()}}))'
elif command -v jq >/dev/null 2>&1; then
  printf '%s' "$combined" | jq -Rs '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:.}}'
else
  exit 0
fi
