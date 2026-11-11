#!/usr/bin/env bash
# resolve-reviewer-model.test.sh — pins the round-1 reviewer model table in
# scripts/resolve-reviewer-model.sh and the REVIEW_MODEL_THRESHOLD output of
# scripts/read-review-config.sh. Hermetic: every config read runs on a temp context file.
#   bash plugins/sdlc/scripts/__tests__/resolve-reviewer-model.test.sh
set -uo pipefail

here="${BASH_SOURCE[0]%/*}"; [ "$here" = "${BASH_SOURCE[0]}" ] && here="."
scripts="$(cd "$here/.." && pwd)"
resolve="$scripts/resolve-reviewer-model.sh"
reader="$scripts/read-review-config.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
failures=0

check() { # <label> <expected> <actual>
  if [ "$2" = "$3" ]; then echo "ok   - $1"; else echo "FAIL - $1: expected '$2', got '$3'"; failures=$((failures + 1)); fi
}

model_of() { bash "$resolve" "$@" 2>/dev/null | sed -n 's/^REVIEWER_MODEL=//p'; }
reason_of() { bash "$resolve" "$@" 2>/dev/null | sed -n 's/^REVIEWER_MODEL_REASON=//p'; }

# --- resolution table ---
check "threshold unset -> opus"         opus   "$(model_of --threshold '' --points 1)"
check "threshold unset reason"          threshold-unset "$(reason_of --threshold '' --points 1)"
check "threshold non-integer -> opus"   opus   "$(model_of --threshold abc --points 1)"
check "bug -> opus even when small"     opus   "$(model_of --threshold 5 --work-kind defect --points 1)"
check "bug reason"                      defect "$(reason_of --threshold 5 --work-kind defect --points 1)"
check "points missing -> opus"          opus   "$(model_of --threshold 5 --points missing)"
check "points absent flag -> opus"      opus   "$(model_of --threshold 5)"
check "points non-integer -> opus"      opus   "$(model_of --threshold 5 --points x)"
check "diff mode -> opus"               opus   "$(model_of --threshold 5 --mode diff --points 1)"
check "diff mode reason"                diff-mode "$(reason_of --threshold 5 --mode diff --points 1)"
check "points below threshold -> sonnet" sonnet "$(model_of --threshold 5 --points 3)"
check "points == threshold -> sonnet"   sonnet "$(model_of --threshold 5 --points 5)"
check "points == threshold reason"      points-within-threshold "$(reason_of --threshold 5 --points 5)"
check "points above threshold -> opus"  opus   "$(model_of --threshold 5 --points 6)"
check "threshold 0, 0 points -> sonnet" sonnet "$(model_of --threshold 0 --points 0)"
check "unknown flag exits 2"            2      "$(bash "$resolve" --bogus >/dev/null 2>&1; echo $?)"

# --- read-review-config.sh: REVIEW_MODEL_THRESHOLD ---
ctx() { printf '## Code Review\n\n| Token | Value |\n| --- | --- |\n| Review agent | `claude-inline` |\n%s\n' "$1" > "$work/ctx.md"; }
out_of() { bash "$reader" "$work/ctx.md" 2>"$work/err"; }

ctx ''
out="$(out_of)"
check "reader: absent -> empty"        "REVIEW_MODEL_THRESHOLD=" "$(printf '%s\n' "$out" | grep '^REVIEW_MODEL_THRESHOLD=')"
check "reader: absent, no warning"     "" "$(grep -i 'reviewer model' "$work/err")"
check "reader: existing lines intact"  "REVIEW_AGENT=claude-inline|REVIEW_MODE=on-update|REVIEW_GATE=" "$(printf '%s\n' "$out" | head -3 | paste -sd'|' -)"

ctx '| Reviewer model threshold (story points, inclusive) | `5` |'
out="$(out_of)"
check "reader: valid -> 5"             "REVIEW_MODEL_THRESHOLD=5" "$(printf '%s\n' "$out" | grep '^REVIEW_MODEL_THRESHOLD=')"
check "reader: valid, no warning"      "" "$(grep -i 'reviewer model' "$work/err")"

ctx '| Reviewer model threshold (story points, inclusive) | five |'
out="$(out_of)"
check "reader: malformed -> empty"     "REVIEW_MODEL_THRESHOLD=" "$(printf '%s\n' "$out" | grep '^REVIEW_MODEL_THRESHOLD=')"
check "reader: malformed warns"        1 "$(grep -c '^WARNING: malformed Reviewer model threshold' "$work/err")"

ctx '| Reviewer model threshold (story points, inclusive) | `2.5` |'
out="$(out_of)"
check "reader: decimal -> empty"       "REVIEW_MODEL_THRESHOLD=" "$(printf '%s\n' "$out" | grep '^REVIEW_MODEL_THRESHOLD=')"

if [ "$failures" -eq 0 ]; then echo "PASS: resolve-reviewer-model"; exit 0; fi
echo "FAIL: $failures resolve-reviewer-model case(s) failed"; exit 1
