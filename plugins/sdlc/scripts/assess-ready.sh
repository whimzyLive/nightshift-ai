#!/usr/bin/env bash
set -uo pipefail
# assess-ready.sh <KEY> — /auto Step 1 fast path: which pickup labels does the story carry?
#
# Prints exactly two lines:
#   AI_READY=yes|no|unknown        labelled AI-Ready -> /auto skips the scrum-master assess dispatch
#   SPEC_APPROVED=yes|no|unknown   labelled Spec-Approved -> a human approved its spec (/spec)
# Exit 0 when both probes answered; exit 1 when either is `unknown` (a failed Jira probe) — the
# caller then falls back to the scrum-master Mode 3 dispatch and treats the spec as unapproved.
#
# JQL label probes, not `acli view --json` — view renders labels as null even when set.

here="$(cd "$(dirname "$0")" && pwd)"
KEY="${1:?usage: assess-ready.sh <KEY>}"

guard_ok=true
bash "$here/jira-site-guard.sh" >/dev/null 2>&1 || guard_ok=false

# has_label <label> -> yes|no|unknown
has_label() {
  local out
  [ "$guard_ok" = true ] || { echo unknown; return; }
  if ! out=$(acli jira workitem search --jql "key = $KEY AND labels = \"$1\"" --fields key --json 2>/dev/null); then
    echo unknown
  elif printf '%s' "$out" | jq -e --arg k "$KEY" 'type == "array" and any(.[]; .key == $k)' >/dev/null 2>&1; then
    echo yes
  elif printf '%s' "$out" | jq -e 'type == "array"' >/dev/null 2>&1; then
    echo no
  else
    echo unknown
  fi
}

ready="$(has_label "AI-Ready")"
approved="$(has_label "Spec-Approved")"
echo "AI_READY=$ready"
echo "SPEC_APPROVED=$approved"
[ "$ready" != unknown ] && [ "$approved" != unknown ]
