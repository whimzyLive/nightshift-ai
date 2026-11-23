#!/usr/bin/env bash
set -uo pipefail
# triage.sh <KEY> [ISSUE_TYPE] — the lightweight-vs-full routing decision (rules: refs/triage.md).
#
# Prints, in order:
#   WARNING: <message>          optional — missing points on a non-Bug, or a malformed threshold
#   WORK_KIND=defect|feature
#   TRIAGE=lightweight|full
#   STORY_POINTS=N|missing
#   THRESHOLD=<T>               the threshold the decision used; not part of the routing contract
# Exit 0 with the block. Any Jira/acli failure exits non-zero with a message on stderr and NO
# WORK_KIND=/TRIAGE= lines: a route is never guessed.
#
# ISSUE_TYPE (optional, any case): when given, no issue-type fetch is made.
# TRIAGE_RETRY_SLEEP: seconds between points-probe attempts (default 2; tests set 0).

here="$(cd "$(dirname "$0")" && pwd)"
KEY="${1:?usage: triage.sh <KEY> [ISSUE_TYPE]}"
ITYPE="$(printf '%s' "${2:-}" | tr '[:upper:]' '[:lower:]')"
RETRY_SLEEP="${TRIAGE_RETRY_SLEEP:-2}"
DEFAULT_T=3

die() { echo "triage.sh: $*" >&2; exit 1; }

# project-context.md: this checkout first, then the primary checkout (a linked worktree of a repo
# whose context file is untracked does not have its own copy), then the session's project dir.
find_ctx() {
  local top common cand
  top="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  common="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  [ -n "$common" ] || common="$(cd "$(git rev-parse --git-common-dir 2>/dev/null)" 2>/dev/null && pwd -P || true)"
  for cand in "$top" "${common%/.git}" "${CLAUDE_PROJECT_DIR:-}" "$PWD"; do
    [ -n "$cand" ] && [ -r "$cand/.claude/project/project-context.md" ] \
      && { printf '%s' "$cand/.claude/project/project-context.md"; return 0; }
  done
  return 1
}

ctx="$(find_ctx)" || die "cannot find .claude/project/project-context.md (checked this checkout, the primary checkout and \$CLAUDE_PROJECT_DIR)"

# Threshold: the `Lightweight threshold` row of the `## Triage` section only. Absent -> default.
WARN=""; WARN2=""
row="$(awk -F'|' '
  /^##[ \t]/ { insec = ($0 ~ /^##[ \t]+Triage[ \t]*$/); next }
  insec && tolower($2) ~ /lightweight threshold/ {
    v = $3; gsub(/^[ \t`]+|[ \t`]+$/, "", v); print "ROW:" v; exit
  }' "$ctx")"
T="$DEFAULT_T"
if [ -n "$row" ]; then
  val="${row#ROW:}"
  if printf '%s' "$val" | grep -qE '^[0-9]+$'; then
    T="$val"
  else
    WARN="Lightweight threshold in project-context.md is not an integer ('$val') — using the built-in default $DEFAULT_T."
  fi
fi

bash "$here/jira-site-guard.sh" "$ctx" >/dev/null 2>&1 \
  || die "Jira site guard failed (acli missing, wrong active site, or no Jira site row in project-context.md)"

if [ -z "$ITYPE" ]; then
  ITYPE="$(acli jira workitem view "$KEY" --fields issuetype --json 2>/dev/null \
    | jq -r '.fields.issuetype.name // empty' | tr '[:upper:]' '[:lower:]')" \
    || die "could not read the issue type of $KEY from Jira"
fi
if [ "$ITYPE" = bug ]; then KIND=defect; else KIND=feature; fi

# probe <jql> -> 0 hit | 1 no hit | 2 acli error or unparseable output. A hit is a non-empty result
# array: the JQL pins `key = $KEY`, and acli can return `[null]` per hit, so the array length is
# counted instead of matching a key.
probe() {
  local out
  out="$(acli jira workitem search --jql "$1" --json 2>/dev/null)" || return 2
  printf '%s' "$out" | jq -e 'type == "array"' >/dev/null 2>&1 || return 2
  printf '%s' "$out" | jq -e 'length > 0' >/dev/null 2>&1 && return 0
  return 1
}

# Points, per refs/jira-fetch.md "Reading story points": find the populated field name (retrying
# across JQL index lag), then probe candidate values on it.
FIELD=""; LAST_ERR=0
for _attempt in 1 2 3; do
  LAST_ERR=0
  for f in "Story point estimate" "Story Points"; do
    rc=0; probe "key = $KEY AND \"$f\" is not EMPTY" || rc=$?
    [ "$rc" -eq 2 ] && LAST_ERR=1
    [ "$rc" -eq 0 ] && { FIELD="$f"; break; }
  done
  [ -n "$FIELD" ] && break
  [ "$_attempt" -lt 3 ] && sleep "$RETRY_SLEEP"
done
if [ -z "$FIELD" ] && [ "$LAST_ERR" -eq 1 ]; then
  die "story-points probe for $KEY errored on every attempt; refusing to report points as missing"
fi

POINTS=missing
if [ -n "$FIELD" ]; then
  CAND_ERR=0
  for v in 1 2 3 5 8 13 20 21 40 0 0.5 1.5 2.5 4 6 7 9 10 11 12 14 15 16 17 18 19 22 24 25 30 34 50 55 80 89 100; do
    rc=0; probe "key = $KEY AND \"$FIELD\" = $v" || rc=$?
    [ "$rc" -eq 0 ] && { POINTS="$v"; break; }
    [ "$rc" -eq 2 ] && CAND_ERR=1
  done
  if [ "$POINTS" = missing ]; then
    [ "$CAND_ERR" -eq 1 ] && die "story-points value probe for $KEY errored; cannot read the points"
    die "\"$FIELD\" is set on $KEY but its value is outside the candidate list; cannot read the points"
  fi
fi

if [ "$KIND" = defect ]; then
  TRIAGE=lightweight
elif [ "$POINTS" = missing ]; then
  TRIAGE=full
  WARN2="Story points not set on $KEY — defaulting to the full (approved-spec) path. Set points in Jira before running /impl for the lightweight path."
elif awk -v p="$POINTS" -v t="$T" 'BEGIN { exit !(p + 0 <= t + 0) }'; then
  TRIAGE=lightweight
else
  TRIAGE=full
fi

[ -z "$WARN" ] || echo "WARNING: $WARN"
[ -z "$WARN2" ] || echo "WARNING: $WARN2"
echo "WORK_KIND=$KIND"
echo "TRIAGE=$TRIAGE"
echo "STORY_POINTS=$POINTS"
echo "THRESHOLD=$T"
