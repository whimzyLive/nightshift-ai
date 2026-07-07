#!/usr/bin/env bash
# session-key.sh — single source of truth for the per-session temp scope key.
# Vendored functional equivalent of the sdlc plugin's session-key.sh — standalone, no sdlc dependency.
#
# Echoes a safe, single path segment (or empty). Resolution order, first match wins:
#   1. GTM_SESSION_KEY        — automation worker / harness (human-readable story key)
#   2. CLAUDE_CODE_SESSION_ID — interactive Claude Code session (stable, unique per session)
#
# This makes the temp scope unique-per-session in BOTH modes: a worker scopes by story key,
# an interactive session scopes by its Claude Code session id. The key is whitelist-validated
# to a single safe path segment — only [A-Za-z0-9._-], and never "." or ".." — so path
# separators, "..", glob metacharacters, or spaces in a malformed/hostile value can never
# escape ./.tmp or expand unexpectedly when a caller interpolates the path. Anything else
# resolves to empty (callers fall back to the bare ./.tmp). Pure env read, no stdin — safe to
# call from tmp-dir.sh on every temp write and from the cleanup/complete scripts at teardown,
# so all of them agree on the same dir.
set -uo pipefail
key="${GTM_SESSION_KEY:-}"
[ -z "$key" ] && key="${CLAUDE_CODE_SESSION_ID:-}"
case "$key" in
  '' | . | .. | *[!A-Za-z0-9._-]*) key='' ;;
esac
printf '%s\n' "$key"
