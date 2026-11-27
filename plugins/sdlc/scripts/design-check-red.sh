#!/usr/bin/env bash
set -uo pipefail
# design-check-red.sh <report-path> — is a design-check report a known failure?
# Report format: refs/design-references.md "Design check". Prints DESIGN_RED=yes|no, then, on yes,
# one `FAILING=<board line>` per `<KEY> fail <ticket>` line. DESIGN_RED=yes only when line 1 starts
# `design-check:` and carries the verdict `fail` or the field `result=fail` (a scoped run's line 1
# is `design-check: partial ...`). A missing, empty or unparseable report is `no`: a red is never
# assumed.

REPORT="${1:-}"
first=""
[ -n "$REPORT" ] && [ -r "$REPORT" ] && first="$(head -n 1 "$REPORT")"

red=no
case "$first" in
  "design-check: "*)
    case " ${first#design-check: } " in
      " fail "* | *" result=fail "*) red=yes ;;
    esac ;;
esac

echo "DESIGN_RED=$red"
if [ "$red" = yes ]; then
  awk 'NR > 1 && $2 == "fail" && $1 !~ /=/ { print "FAILING=" $0 }' "$REPORT"
fi
