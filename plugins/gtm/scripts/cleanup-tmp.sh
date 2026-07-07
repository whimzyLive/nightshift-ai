#!/usr/bin/env bash
# cleanup-tmp.sh — SessionEnd safety net. Removes THIS session's own scoped temp dir
# (./.tmp/<key>, worker OR interactive), so its scratch never survives a session that errored
# or was interrupted before session-complete.sh ran. Always exits 0 — a cleanup failure must
# never block session teardown.
# Vendored functional equivalent of the sdlc plugin's cleanup-tmp.sh — standalone, no sdlc dependency.
#
# Deliberately SCOPED-ONLY: it removes just this session's own ./.tmp/<key> dir and never sweeps
# loose ./.tmp/* files. It additionally prunes the ./.tmp parent itself, but only via `rmdir`,
# which succeeds only when the parent is already empty — so it can never delete a concurrent
# session's in-flight files. The flip side is that callers must write temp files INTO the scoped
# dir from tmp-dir.sh (not bare ./.tmp/<file>); anything written outside the scoped dir is the
# writer's own responsibility to clean (e.g. via a `trap`).
#
# Key resolution comes from session-key.sh, which reads GTM_SESSION_KEY / CLAUDE_CODE_SESSION_ID
# from the environment. The SessionEnd hook inherits that environment, so no stdin parsing is
# needed.
set -uo pipefail
# Dir of this script (fork-free; fall back to "." on a slash-less invocation — see tmp-dir.sh).
here="${BASH_SOURCE[0]%/*}"; [ "$here" = "${BASH_SOURCE[0]}" ] && here="."
key="$(bash "$here/session-key.sh" 2>/dev/null || true)"
[ -n "$key" ] && rm -rf "./.tmp/$key" 2>/dev/null || true
rmdir ./.tmp 2>/dev/null || true   # best-effort: prunes the parent only if now empty
exit 0
