#!/usr/bin/env bash
set -euo pipefail
# resolve-reviewer-model.sh --threshold <int|''> [--mode story|diff] [--work-kind defect|feature]
#                           [--points <N|missing>]
#
# Picks the model for the FIRST (exhaustive) QA code-review round and prints, to stdout:
#
#   REVIEWER_MODEL=sonnet|opus
#   REVIEWER_MODEL_REASON=<token>
#
# --threshold is REVIEW_MODEL_THRESHOLD from read-review-config.sh (empty = unset). A pure function
# of its arguments, so the callers' eval of read-review-config.sh stays the only context read.
# First match wins:
#   threshold unset/non-integer -> opus   (reason: threshold-unset)
#   --mode diff                 -> opus   (diff-mode)
#   --work-kind defect (a Bug)  -> opus   (defect)
#   points missing/non-integer  -> opus   (points-unknown)
#   points <= threshold         -> sonnet (points-within-threshold)
#   points >  threshold         -> opus   (points-above-threshold)
#
# Fresh scoped re-reviews are always sonnet and do not call this script.

THRESHOLD=""; MODE="story"; WORK_KIND="feature"; POINTS="missing"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --threshold)  THRESHOLD="${2:-}"; shift 2 ;;
    --mode)       MODE="${2:-story}"; shift 2 ;;
    --work-kind)  WORK_KIND="${2:-feature}"; shift 2 ;;
    --points)     POINTS="${2:-missing}"; shift 2 ;;
    *) echo "resolve-reviewer-model.sh: unknown argument '$1'" >&2; exit 2 ;;
  esac
done

emit() { printf 'REVIEWER_MODEL=%s\nREVIEWER_MODEL_REASON=%s\n' "$1" "$2"; exit 0; }
is_int() { case "$1" in ''|*[!0-9]*) return 1 ;; *) return 0 ;; esac; }

is_int "$THRESHOLD" || emit opus threshold-unset
[ "$MODE" = diff ] && emit opus diff-mode
[ "$WORK_KIND" = defect ] && emit opus defect
is_int "$POINTS" || emit opus points-unknown
if [ "$POINTS" -le "$THRESHOLD" ]; then
  emit sonnet points-within-threshold
fi
emit opus points-above-threshold
