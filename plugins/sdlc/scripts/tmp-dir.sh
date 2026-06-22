#!/usr/bin/env bash
# tmp-dir.sh — echoes (and creates) the session-scoped temp dir. Unique per session in BOTH
# modes, so setup here pairs with cleanup-tmp.sh / session-complete.sh removing the same dir:
#   worker      (SDLC_SESSION_KEY set)       -> ./.tmp/<story-key>
#   interactive (CLAUDE_CODE_SESSION_ID set) -> ./.tmp/<session-id>
#   neither resolvable                       -> bare ./.tmp (last resort)
# Key resolution and the path-traversal guard live in session-key.sh (single source of truth).
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
key="$(bash "$here/session-key.sh")"
dir="./.tmp${key:+/$key}"
mkdir -p "$dir"
printf '%s\n' "$dir"
