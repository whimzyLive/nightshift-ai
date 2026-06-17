#!/usr/bin/env bash
# Echoes the session-scoped temp dir (and creates it).
# SDLC_SESSION_KEY set (worker/automation) -> ./.tmp/<key>; unset (local dev) -> ./.tmp
set -euo pipefail
key="${SDLC_SESSION_KEY:-}"
# Guard against path traversal: only scope to a subdir when $key is a single safe path
# segment. A key containing a path separator or `..` is rejected (fall back to the unscoped
# ./.tmp) so a malformed/hostile SDLC_SESSION_KEY can never escape the temp area.
case "$key" in
  */* | *..*) key='' ;;
esac
dir="./.tmp${key:+/$key}"
mkdir -p "$dir"
printf '%s\n' "$dir"
