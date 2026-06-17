#!/usr/bin/env bash
# Echoes the session-scoped temp dir (and creates it).
# SDLC_SESSION_KEY set (worker/automation) -> ./.tmp/<key>; unset (local dev) -> ./.tmp
set -euo pipefail
key="${SDLC_SESSION_KEY:-}"
dir="./.tmp${key:+/$key}"
mkdir -p "$dir"
printf '%s\n' "$dir"
