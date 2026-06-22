#!/usr/bin/env bash
# tmp-dir.sh — echoes (and creates) the session-scoped temp dir. Unique per session in BOTH
# modes, so setup here pairs with cleanup-tmp.sh / session-complete.sh removing the same dir:
#   worker      (SDLC_SESSION_KEY set)       -> ./.tmp/<story-key>
#   interactive (CLAUDE_CODE_SESSION_ID set) -> ./.tmp/<session-id>
#   neither resolvable / session-key.sh absent -> bare ./.tmp (last resort)
# Key resolution and the path-traversal guard live in session-key.sh (single source of truth).
# NOTE: key resolution is deliberately non-fatal (|| true, no `set -e`): if session-key.sh is
# missing or unreadable we MUST still fall back to bare ./.tmp and print a usable dir, never
# abort with empty output — an empty $dir would turn a caller's `mktemp "$dir/x"` into a write
# to the filesystem root.
set -uo pipefail
here="${BASH_SOURCE[0]%/*}"
key="$(bash "$here/session-key.sh" 2>/dev/null || true)"
dir="./.tmp${key:+/$key}"
mkdir -p "$dir" 2>/dev/null || true
printf '%s\n' "$dir"
