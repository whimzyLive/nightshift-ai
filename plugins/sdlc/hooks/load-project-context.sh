#!/usr/bin/env bash
# SessionStart hook for the sdlc plugin. Three jobs:
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
#   3. VERSION-DRIFT WARNING. When the resolved plugin root is a versioned cache dir
#      (.../sdlc/<semver>) and a NEWER version is also installed in the cache, the session is
#      running an OLDER playbook than what is installed — surface a loud warning in
#      additionalContext so the operator restarts/refreshes instead of silently running stale
#      command/ref/script behavior.
#
# Inert-safe: in a repo with neither a .claude dir nor project-context, emits nothing, exit 0.
set -euo pipefail

proj="${CLAUDE_PROJECT_DIR:-$PWD}"
plugin_root="${CLAUDE_PLUGIN_ROOT:-}"

# (1) Drop the plugin-root marker (best-effort: needs the var + an existing .claude dir).
if [ -n "$plugin_root" ] && [ -d "$proj/.claude" ]; then
  printf '%s\n' "$plugin_root" > "$proj/.claude/.sdlc-plugin-root" 2>/dev/null || true
fi

# (1.5) VERSION-DRIFT DETECTION (best-effort). The plugin root resolves to a versioned cache dir
# (.../sdlc/<semver>); its parent holds every installed version. If a newer version exists in the
# cache than the one this session resolved, we are running a stale playbook — surface a warning.
# Inert when the root is not a versioned dir (e.g. a dev/source checkout) or only one version is
# installed. Never fails the hook (set -e safe: the lookup pipeline is guarded with `|| true`).
drift=""
if [ -n "$plugin_root" ]; then
  running_ver="$(basename "$plugin_root")"
  if printf '%s' "$running_ver" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    latest_ver="$(ls -1 "$(dirname "$plugin_root")" 2>/dev/null \
      | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n1 || true)"
    if [ -n "$latest_ver" ] && [ "$latest_ver" != "$running_ver" ] \
       && [ "$(printf '%s\n%s\n' "$running_ver" "$latest_ver" | sort -V | tail -n1)" = "$latest_ver" ]; then
      drift="⚠️ SDLC PLUGIN DRIFT: this session resolved sdlc plugin v${running_ver}, but a newer v${latest_ver} is installed in the plugin cache. You are running an OLDER playbook — newer command/ref/script behavior will NOT take effect. Restart the session (or refresh the plugin) so \${CLAUDE_PLUGIN_ROOT} resolves to v${latest_ver}."
    fi
  fi
fi

# (2) Assemble additionalContext: drift warning (if any) + root mapping (if known) + project-context.
intro=""
if [ -n "$plugin_root" ]; then
  intro="SDLC plugin root (this session): ${plugin_root}
When any SDLC agent, command, or ref instruction references \${CLAUDE_PLUGIN_ROOT}/..., resolve it against that absolute path. A subagent that does not see this note can read the same value from the repo-relative file .claude/.sdlc-plugin-root."
  # Surface any drift warning ABOVE the root mapping so it is the first thing the session sees.
  [ -n "$drift" ] && intro="${drift}

${intro}"
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
