#!/usr/bin/env bash
# check-plan.sh <plan-path> — checks a plan against the tech-lead template: the Spec / Date / Agents
# required header lines, an `## Execution order` section, at least one `## Phase N — ...` section,
# a checkbox task in every phase, a `Verify:` task closing every phase, and no TBD.
#
#   exit 0  OK
#   exit 1  one `MISSING=<what>`, `NO_TASKS=<phase heading>`, `NO_VERIFY=<phase heading>` or
#           `TBD=<line>` line per problem
#   exit 2  unreadable path

set -uo pipefail

plan="${1:-}"
[ -n "$plan" ] && [ -r "$plan" ] || { echo "check-plan.sh: usage: check-plan.sh <plan-path> (unreadable: ${plan:-none})" >&2; exit 2; }

report="$(awk '
  function close_phase() {
    if (phase != "") {
      if (!tasks) printf "NO_TASKS=%s\n", phase
      else if (!last_verify) printf "NO_VERIFY=%s\n", phase
    }
    phase = ""; tasks = 0; last_verify = 0
  }
  /^```/ { fence = !fence; next }
  fence { next }
  /^\*\*Spec:\*\*/ { spec = 1 }
  /^\*\*Date:\*\*/ { date = 1 }
  /^\*\*Agents required:\*\*/ { agents = 1 }
  /^## Execution order/ { close_phase(); order = 1; next }
  /^## Phase [0-9]+ / { close_phase(); phase = $0; phases++; next }
  /^## / { close_phase(); next }
  phase != "" && /^- \[[ xX]\] / { tasks++; last_verify = ($0 ~ /Verify:/) }
  /(^|[^A-Za-z])TBD([^A-Za-z]|$)/ { printf "TBD=%d\n", NR }
  END {
    close_phase()
    if (!spec) print "MISSING=**Spec:** line"
    if (!date) print "MISSING=**Date:** line"
    if (!agents) print "MISSING=**Agents required:** line"
    if (!order) print "MISSING=## Execution order"
    if (!phases) print "MISSING=## Phase N section"
  }
' "$plan")"

if [ -n "$report" ]; then
  printf '%s\n' "$report"
  exit 1
fi
echo "check-plan: OK"
