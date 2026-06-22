#!/usr/bin/env bash
# cleanup-tmp.sh — SessionEnd safety net. Removes THIS session's own scoped temp dir
# (./.tmp/<key>, worker OR interactive), so its scratch never survives a session that errored
# or was interrupted before session-complete.sh ran. Always exits 0 — a cleanup failure must
# never block session teardown.
#
# Deliberately SCOPED-ONLY: it removes just this session's dir and never sweeps loose ./.tmp/*
# files or any other path. That keeps it safe when several sessions share one checkout — it can
# never delete a concurrent session's in-flight files. The flip side is that callers must write
# temp files INTO the scoped dir from tmp-dir.sh (not bare ./.tmp/<file>); anything written
# outside the scoped dir is the writer's own responsibility to clean (e.g. via a `trap`).
#
# Key resolution comes from session-key.sh, which reads SDLC_SESSION_KEY / CLAUDE_CODE_SESSION_ID
# from the environment. The SessionEnd hook inherits that environment, so no stdin parsing is
# needed.
set -uo pipefail
here="${BASH_SOURCE[0]%/*}"
key="$(bash "$here/session-key.sh" 2>/dev/null || true)"
[ -n "$key" ] && rm -rf "./.tmp/$key" 2>/dev/null || true
rmdir ./.tmp 2>/dev/null || true   # best-effort: only succeeds if now empty
exit 0
