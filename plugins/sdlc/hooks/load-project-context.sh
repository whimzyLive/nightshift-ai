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
#   4. REPO-BEHIND WARNING. In the primary checkout, when the base branch (or the current epic/*
#      trunk) is behind origin, warn so story runs do not start from stale code. Best-effort:
#      bounded fetch, any failure means no warning.
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
# installed. Never fails the hook: EVERY pipeline that could error under `pipefail` (incl. `sort -V`
# on a platform that lacks it) is `2>/dev/null`-silenced and `|| true`-guarded, so the safety is
# local and does not rely on the surrounding `if`-context. On a `sort -V`-less platform the feature
# simply goes inert (no warning) rather than aborting.
drift=""
if [ -n "$plugin_root" ]; then
  running_ver="$(basename "$plugin_root")"
  if printf '%s' "$running_ver" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    latest_ver="$(ls -1 "$(dirname "$plugin_root")" 2>/dev/null \
      | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V 2>/dev/null | tail -n1 || true)"
    max_ver="$(printf '%s\n%s\n' "$running_ver" "$latest_ver" | sort -V 2>/dev/null | tail -n1 || true)"
    if [ -n "$latest_ver" ] && [ "$latest_ver" != "$running_ver" ] && [ "$max_ver" = "$latest_ver" ]; then
      drift="⚠️ SDLC PLUGIN DRIFT: this session resolved sdlc plugin v${running_ver}, but a newer v${latest_ver} is installed in the plugin cache. You are running an OLDER playbook — newer command/ref/script behavior will NOT take effect. Restart the session (or refresh the plugin) so \${CLAUDE_PLUGIN_ROOT} resolves to v${latest_ver}."
    fi
  fi
fi

# (1.6) REPO-BEHIND DETECTION (best-effort, read-only apart from one bounded fetch). Primary
# checkout only; compares HEAD with origin/<ref> where <ref> is the current branch when it is the
# base branch or epic/*, else the base branch. Every failure path leaves `behind_warn` empty.
behind_warn=""
if gdir="$(git -C "$proj" rev-parse --git-dir 2>/dev/null)" \
  && gcommon="$(git -C "$proj" rev-parse --git-common-dir 2>/dev/null)" \
  && [ "$(cd "$proj" && cd "$gdir" && pwd -P)" = "$(cd "$proj" && cd "$gcommon" && pwd -P)" ] \
  && git -C "$proj" remote get-url origin >/dev/null 2>&1; then
  base_branch="$(grep -iE '^\|[[:space:]]*Base branch[[:space:]]*\|' "$proj/.claude/project/project-context.md" 2>/dev/null \
    | sed -E 's/.*\|[^|]*\|[[:space:]]*`?([A-Za-z0-9_.\/-]+)`?[[:space:]]*\|.*/\1/' \
    | head -1 || true)"
  base_branch="${base_branch:-main}"
  cur_branch="$(git -C "$proj" symbolic-ref --short -q HEAD 2>/dev/null || true)"
  ref="$base_branch"
  case "$cur_branch" in "$base_branch" | epic/*) ref="$cur_branch" ;; esac
  # No `timeout` on macOS: run the fetch in the background and stop it after ~5s.
  GIT_TERMINAL_PROMPT=0 git -C "$proj" fetch --quiet origin "$ref" </dev/null >/dev/null 2>&1 &
  fetch_pid=$!
  for _ in $(seq 1 50); do
    kill -0 "$fetch_pid" 2>/dev/null || break
    sleep 0.1
  done
  kill "$fetch_pid" 2>/dev/null || true
  if wait "$fetch_pid" 2>/dev/null; then
    behind="$(git -C "$proj" rev-list --count "HEAD..origin/$ref" 2>/dev/null || true)"
    if [ -n "$behind" ] && [ "$behind" -gt 0 ] 2>/dev/null; then
      behind_warn="⚠️ REPO BEHIND: this checkout is ${behind} commit(s) behind origin/${ref}. Pull before starting story work."
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
if [ -n "$behind_warn" ]; then
  if [ -n "$intro" ]; then intro="${behind_warn}

${intro}"; else intro="$behind_warn"; fi
fi

ctx="$proj/.claude/project/project-context.md"
body=""
[ -f "$ctx" ] && body="$(cat "$ctx")"

# (2.5) AGENT ROUTING. Ad-hoc code edits handed to general-purpose agents inherit the main session's
# model (often Opus) and skip the domain agent's rules; point them at the owning sdlc agent instead.
case "$body" in *'## Workspace → agent'*)
  body="${body}

## Agent routing

When you hand a code change to a subagent outside the sdlc commands, dispatch the owning \`sdlc:<agent>\` from the Workspace → agent table above, never \`general-purpose\`: a general-purpose agent inherits this session's model and skips the domain agent's rules. Read-only search, review, and research may still use \`general-purpose\` or \`Explore\`.

Every \`general-purpose\` or \`Explore\` dispatch passes \`model: \"sonnet\"\` instead of inheriting this session's model — unless the command, playbook, or ref you are following names a model for that dispatch (the QA code reviewer's model comes from the optional \`Reviewer model threshold\` in \`## Code Review\`: \`opus\` unless the story is at or under it, and \`sonnet\` on fresh scoped re-reviews). A dispatch that only runs fixed commands and reports their output — a predefined command, a test or CI run, a build, a lint — passes \`model: \"haiku\"\`: it needs no reasoning."
  ;;
esac

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
