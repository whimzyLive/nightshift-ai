#!/usr/bin/env bash
# session-key.sh — single source of truth for the per-session temp scope key.
#
# Echoes a safe, single path segment (or empty). Resolution order, first match wins:
#   1. SDLC_SESSION_KEY      — automation worker / harness (human-readable story key)
#   2. CLAUDE_CODE_SESSION_ID — interactive Claude Code session (stable, unique per session)
#
# This makes the temp scope unique-per-session in BOTH modes: a worker scopes by story key,
# an interactive session scopes by its Claude Code session id. A key containing a path
# separator or `..` is rejected (echoes empty) so a malformed/hostile value can never escape
# ./.tmp. Pure env read, no stdin — safe to call from tmp-dir.sh on every temp write, and
# from the cleanup/complete scripts at teardown, so all of them agree on the same dir.
set -euo pipefail
key="${SDLC_SESSION_KEY:-}"
[ -z "$key" ] && key="${CLAUDE_CODE_SESSION_ID:-}"
case "$key" in
  */* | *..*) key='' ;;
esac
printf '%s\n' "$key"
