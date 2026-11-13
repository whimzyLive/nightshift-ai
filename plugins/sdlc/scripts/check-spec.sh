#!/usr/bin/env bash
# check-spec.sh <spec-path> — checks a spec against the writing-specs template: every always-present
# heading exists (as `## <name>`, outside code fences) and the spec carries no TBD.
#
#   exit 0  OK
#   exit 1  one `MISSING=<heading>` line per absent heading and one `TBD=<line>` per TBD line
#   exit 2  unreadable path
#
# Sections the template lets a story omit (Web UI, Mobile UI, Offline Sync, Backend Implementation)
# are not required.

set -uo pipefail

spec="${1:-}"
[ -n "$spec" ] && [ -r "$spec" ] || { echo "check-spec.sh: usage: check-spec.sh <spec-path> (unreadable: ${spec:-none})" >&2; exit 2; }

required=("Overview" "Data Model" "API Surface" "Design & Dev Notes" "Reuse" "Error Handling" "Out of Scope" "Decisions")

report="$(awk -v req="$(IFS='|'; echo "${required[*]}")" '
  BEGIN { n = split(req, r, "|"); for (i = 1; i <= n; i++) need[r[i]] = 1 }
  /^```/ { fence = !fence; next }
  fence { next }
  /^## / { h = substr($0, 4); sub(/[[:space:]]+$/, "", h); seen[h] = 1 }
  /(^|[^A-Za-z])TBD([^A-Za-z]|$)/ { printf "TBD=%d\n", NR }
  END { for (i = 1; i <= n; i++) if (!(r[i] in seen)) printf "MISSING=%s\n", r[i] }
' "$spec")"

if [ -n "$report" ]; then
  printf '%s\n' "$report"
  exit 1
fi
echo "check-spec: OK"
