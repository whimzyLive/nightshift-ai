#!/usr/bin/env bash
# SessionStart hook: inject the consumer repo's SDLC project config as additionalContext.
# Inert (emits nothing) in repos that have no .claude/project/project-context.md.
set -euo pipefail

root="${CLAUDE_PROJECT_DIR:-$PWD}"
ctx="$root/.claude/project/project-context.md"

[ -f "$ctx" ] || exit 0

if command -v python3 >/dev/null 2>&1; then
  python3 - "$ctx" <<'PY'
import json, sys
with open(sys.argv[1], "r", encoding="utf-8") as f:
    body = f.read()
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": body,
    }
}))
PY
elif command -v jq >/dev/null 2>&1; then
  jq -Rs '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:.}}' "$ctx"
else
  exit 0
fi
