#!/usr/bin/env bash
# cleanup-tmp.sh — SessionEnd safety net. Removes THIS session's scoped temp dir (worker OR
# interactive) AND sweeps loose unscoped temp files, so no .tmp artifacts survive a session —
# even one that errored or was interrupted before session-complete.sh ran. Always exits 0:
# a cleanup failure must never block session teardown.
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || here="."

# Primary: resolve the session key from the environment (SDLC_SESSION_KEY / CLAUDE_CODE_SESSION_ID)
# via the shared resolver, so we remove exactly the dir tmp-dir.sh created for this session.
key="$(bash "$here/session-key.sh" 2>/dev/null || true)"

# Fallback: the SessionEnd hook delivers {"session_id":...} on stdin. Only read when stdin is a
# pipe (never block on a tty if the script is run by hand). Env resolution above is the normal path.
if [ -z "$key" ] && [ ! -t 0 ]; then
  payload="$(cat 2>/dev/null || true)"
  if [ -n "$payload" ]; then
    if command -v python3 >/dev/null 2>&1; then
      key="$(printf '%s' "$payload" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("session_id",""))' 2>/dev/null || true)"
    elif command -v jq >/dev/null 2>&1; then
      key="$(printf '%s' "$payload" | jq -r '.session_id // empty' 2>/dev/null || true)"
    fi
    case "$key" in */* | *..*) key='' ;; esac   # re-guard a stdin-sourced key
  fi
fi

[ -n "$key" ] && rm -rf "./.tmp/$key" 2>/dev/null || true
# Defensive sweep of loose unscoped temp files (e.g. a consumer repo whose own conventions write
# bare ./.tmp/<file> outside the scoped dir).
rm -f ./.tmp/commit-msg.txt ./.tmp/acli-* ./.tmp/*.tmp 2>/dev/null || true
rmdir ./.tmp 2>/dev/null || true   # only succeeds if now empty
exit 0
