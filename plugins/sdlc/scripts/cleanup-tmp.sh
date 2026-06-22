#!/usr/bin/env bash
# cleanup-tmp.sh — SessionEnd safety net: remove this session's scoped temp dir AND
# sweep loose unscoped temp files, so no .tmp artifacts survive a session (even one
# that errored or was interrupted before session-complete.sh ran).
set -uo pipefail
key="${SDLC_SESSION_KEY:-}"
case "$key" in
  */* | *..*) key='' ;;            # unsafe key — never rm a traversable path
esac
[ -n "$key" ] && rm -rf "./.tmp/$key" 2>/dev/null || true
# Sweep unscoped loose temp files left by call sites that wrote bare ./.tmp/<file>.
rm -f ./.tmp/commit-msg.txt ./.tmp/acli-* ./.tmp/*.tmp 2>/dev/null || true
rmdir ./.tmp 2>/dev/null || true   # only succeeds if now empty
exit 0
