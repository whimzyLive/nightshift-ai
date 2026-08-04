#!/usr/bin/env bash
set -u
payload="$(cat)"
cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // ""')"
case "$cmd" in
  *"<<"*) exit 0 ;;
esac
new="$(printf '%s' "$cmd" | sed 's/^git status$/rtk git status/; s/^grep -n a b.md$/rtk grep -n a b.md/')"
[ "$new" != "$cmd" ] || exit 0
printf '%s' "$payload" | jq -c --arg c "$new" \
  '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"allow",permissionDecisionReason:"stub",updatedInput:(.tool_input|.command=$c)}}'
