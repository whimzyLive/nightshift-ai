#!/usr/bin/env bash
#
# rtk-line-scan — PreToolUse/Bash wrapper applying rtk's own rewrite engine to EVERY line of a
# multi-line command, not just line 1 (NA-89 F3). All eligibility is delegated to
# `rtk hook check`; this script reimplements no matching logic.
#
# Failure is ALWAYS passthrough: emit nothing, exit 0, harness runs the raw command.

set -u

# EXCLUDE — verification-critical heads that must never be rtk-wrapped.
# A line is carried through untouched if ANY top-level segment resolves to one of these.
EXCLUDE="tsc prettier nx eslint lint vitest jest pytest"   # ADR 0015

emit_nothing() { exit 0; }

command -v rtk >/dev/null 2>&1 || emit_nothing
command -v jq >/dev/null 2>&1 || emit_nothing

payload="$(cat)"
[ -n "$payload" ] || emit_nothing
printf '%s' "$payload" | jq -e . >/dev/null 2>&1 || emit_nothing

tool_name="$(printf '%s' "$payload" | jq -r '.tool_name // ""')"
[ "$tool_name" = "Bash" ] || emit_nothing

cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // ""')"
[ -n "$cmd" ] || emit_nothing

case "$cmd" in
  *"<<"*) emit_nothing ;;
esac

scan_quote_state() {
  local line="$1" state="$2" i ch n
  n=${#line}
  i=0
  while [ "$i" -lt "$n" ]; do
    ch="${line:$i:1}"
    case "$state" in
      "")
        case "$ch" in
          "\\") i=$((i + 1)) ;;
          "'") state="'" ;;
          '"') state='"' ;;
        esac
        ;;
      "'")
        [ "$ch" = "'" ] && state=""
        ;;
      '"')
        case "$ch" in
          "\\") i=$((i + 1)) ;;
          '"') state="" ;;
        esac
        ;;
    esac
    i=$((i + 1))
  done
  printf '%s' "$state"
}

resolve_head() {
  local seg="$1" w
  # shellcheck disable=SC2086
  set -- $seg
  while [ "$#" -gt 0 ]; do
    w="$1"
    case "$w" in
      *=*) shift; continue ;;
      pnpm|npm|yarn|bun|npx|bunx|pnpx) shift; continue ;;
      exec|dlx|run|x) shift; continue ;;
      *) break ;;
    esac
  done
  [ "$#" -gt 0 ] || return 0
  w="${1##*/}"
  printf '%s' "$w" | tr '[:upper:]' '[:lower:]'
}

line_is_excluded() {
  local line="$1" seg head normalised
  normalised="$(printf '%s' "$line" | sed 's/&&/\n/g; s/||/\n/g; s/[;|]/\n/g')"
  while IFS= read -r seg; do
    head="$(resolve_head "$seg")"
    [ -n "$head" ] || continue
    case " $EXCLUDE " in
      *" $head "*) return 0 ;;
    esac
  done <<SEGMENTS
$normalised
SEGMENTS
  return 1
}

ends_with_continuation() {
  local line="$1" tail
  tail="${line##*[!\\]}"
  [ -n "$tail" ] && [ $(( ${#tail} % 2 )) -eq 1 ]
}

RTK_TIMEOUT=""
if command -v timeout >/dev/null 2>&1; then
  RTK_TIMEOUT="timeout 2"
elif command -v gtimeout >/dev/null 2>&1; then
  RTK_TIMEOUT="gtimeout 2"
fi

rewrite_line() {
  local line="$1" out
  out="$($RTK_TIMEOUT rtk hook check -- "$line" 2>/dev/null)" || return 1
  [ -n "$out" ] || return 1
  printf '%s' "$out"
}

changed=0
continued=0
quote_state=""
out_lines=""
first=1

while IFS= read -r line || [ -n "$line" ]; do
  keep="$line"
  if [ -n "$quote_state" ] || [ "$continued" -eq 1 ]; then
    :
  elif [ -z "${line//[[:space:]]/}" ]; then
    :
  elif line_is_excluded "$line"; then
    :
  else
    indent="${line%%[![:space:]]*}"
    if rewritten="$(rewrite_line "$line")"; then
      rewritten="$indent$rewritten"
      if [ "$rewritten" != "$line" ]; then
        keep="$rewritten"
        changed=1
      fi
    fi
  fi
  quote_state="$(scan_quote_state "$line" "$quote_state")"
  if ends_with_continuation "$line"; then continued=1; else continued=0; fi
  if [ "$first" -eq 1 ]; then
    out_lines="$keep"
    first=0
  else
    out_lines="$out_lines
$keep"
  fi
done <<COMMAND
$cmd
COMMAND

[ "$changed" -eq 1 ] || emit_nothing
[ "$out_lines" != "$cmd" ] || emit_nothing

# `permissionDecision: "allow"` is DELIBERATE, not an oversight (NA-89 spec D3) — the harness
# was independently observed to honour `updatedInput` even with no `permissionDecision` field
# (upstream `rtk hook claude`, live end-to-end test), so it is not required to make the rewrite
# take effect. It is emitted anyway because the upstream engine's own hook output was observed
# to include it inconsistently across code paths; always emitting it here removes this wrapper's
# behaviour from that undocumented harness leniency. Pinned by
# `.claude/hooks/__tests__/rtk-line-scan.test.sh` ("permissionDecision is always emitted on a
# rewrite") — do not drop this field without updating that test and re-verifying the harness
# still applies `updatedInput` for every caller-configured permission mode (not just the
# already-allowed case this hook has been exercised under).
printf '%s' "$payload" | jq -c --arg c "$out_lines" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "allow",
    permissionDecisionReason: "RTK line-scan rewrite",
    updatedInput: (.tool_input | .command = $c)
  }
}'
exit 0
