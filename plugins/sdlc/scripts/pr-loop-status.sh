#!/usr/bin/env bash
set -euo pipefail
# pr-loop-status.sh <pr> [out_file]
#
# One-shot status probe for the /loop polling cycle. Prints a single greppable
# line: whether Copilot has reviewed the current HEAD, whether Copilot is
# currently a pending reviewer, how many UNRESOLVED inline review threads were
# authored by Copilot, plus the PR's status-check tallies (pending / failing /
# passing). Optionally writes the unresolved Copilot comments as NDJSON to
# <out_file> (same shape as pr-unresolved-comments.sh) so /loop can hand them
# to /review-fix.
#
# Output line format:
#   loop-status: copilot-reviewed-head=<0|1> copilot-changes-requested=<0|1> copilot-pending=<0|1> unresolved-copilot=<N> checks-pending=<P> checks-failing=<F> checks-passing=<S> copilot-reviewed-any=<0|1>
#   copilot-changes-requested=1 ⇒ Copilot's LATEST review on the current head is CHANGES_REQUESTED
#   (must NOT be treated as clean even if unresolved-copilot=0, e.g. a summary-only request).
#
# copilot-reviewed-head=1  Copilot's latest review was submitted against the
#                          current HEAD commit (commit_id matches headRefOid).
# copilot-reviewed-any=1   Copilot has submitted AT LEAST ONE review on this PR (any commit).
#                          RELIABLE (REST reviews API). Combined with reviewed-head=0 & pending=0 it
#                          tells the loop whether to keep waiting: reviewed-any=0 ⇒ the INITIAL review
#                          has not started (wait with full patience); reviewed-any=1 ⇒ Copilot
#                          reviewed an EARLIER head but is not re-reviewing the current one and
#                          nothing is queued ⇒ a re-review may never come (review-on-push limited) ⇒
#                          wait only a short grace, then stop.
# copilot-pending=1        Copilot is currently listed in reviewRequests for the PR.
#                          BEST-EFFORT: gh pr view --json reviewRequests does not
#                          reliably list bot reviewers (incl. the Copilot bot), so
#                          this field may stay 0 even when a review is in-flight.
#                          copilot-pending=1 is an optimisation: it suppresses a
#                          redundant re-request while a review is confirmed mid-flight.
#                          When it is always 0 the loop still behaves correctly via the
#                          reviewed-head / reviewed-any split (initial wait vs short re-review grace).
#
# Why a script: GraphQL reviewThreads + checks rollup + jq + pagination cannot be
# statically analyzed on a Bash command line — it lives here so the auto-mode
# allowlist (Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/*)) matches. Best-effort:
# always exits 0; a probe failure prints zeros and is handled by the loop.

PR="$1"; OUT="${2:-}"
SLUG=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "unknown/unknown")
OWNER="${SLUG%/*}"; REPO="${SLUG#*/}"
PR_NUM="${PR##*/}"

# Copilot review-bot login(s). GitHub's Copilot reviewer posts as this bot login.
COPILOT_LOGIN_RE='^(copilot-pull-request-reviewer|copilot)(\[bot\])?$'

# ── HEAD oid ────────────────────────────────────────────────────────────────
head_oid=$(gh pr view "$PR_NUM" --json headRefOid -q .headRefOid 2>/dev/null || echo "")

# ── Copilot pending reviewer ─────────────────────────────────────────────────
# reviewRequests[].login (users) or reviewRequests[].slug (teams)
review_requests=$(gh pr view "$PR_NUM" --json reviewRequests 2>/dev/null || echo '{"reviewRequests":[]}')
copilot_pending=$(printf '%s' "$review_requests" \
  | jq --arg re "$COPILOT_LOGIN_RE" \
    '[(.reviewRequests // [])[] | (.login // .slug // "") | ascii_downcase | test($re)] | any | if . then 1 else 0 end' \
    2>/dev/null || echo 0)

# ── Latest Copilot review commit ────────────────────────────────────────────
# Fetch all reviews, filter for Copilot bot, pick the latest by submitted_at,
# extract its commit_id, compare to head_oid.
reviews_raw=$(gh api "repos/$OWNER/$REPO/pulls/$PR_NUM/reviews" --paginate 2>/dev/null || echo '[]')
# Capture BOTH the latest Copilot review's commit AND its state (tab-separated), so the loop can
# distinguish an APPROVED/COMMENTED head review (clean-eligible) from a CHANGES_REQUESTED one
# (must NOT be treated as clean even with zero unresolved inline threads — e.g. a summary-only
# changes-requested review).
copilot_latest=$(printf '%s' "$reviews_raw" \
  | jq -r --arg re "$COPILOT_LOGIN_RE" \
    '[.[] | select((.user.login // "") | ascii_downcase | test($re))
          | select((.state // "") | test("APPROVED|CHANGES_REQUESTED|COMMENTED"))]
     | sort_by(.submitted_at)
     | last
     | "\(.commit_id // "")\t\(.state // "")"' \
    2>/dev/null || printf '\t')
copilot_latest_commit=$(printf '%s' "$copilot_latest" | cut -f1)
copilot_latest_state=$(printf '%s' "$copilot_latest" | cut -f2)

# copilot_reviewed_any: 1 if Copilot has submitted ANY review on this PR (on any commit). This is a
# RELIABLE signal (REST reviews API, like copilot-reviewed-head). It lets the loop distinguish two
# states that copilot-pending=0 alone cannot: (a) Copilot has not started the INITIAL review yet
# (reviewed-any=0 → wait with full patience — a queueing review may not show as pending), versus
# (b) Copilot already reviewed an EARLIER head but is NOT re-reviewing the current one and nothing is
# queued (reviewed-any=1, reviewed-head=0, pending=0 → a re-review may never come, e.g. when the
# repo's Copilot review-on-push is limited/rate-limited → wait only a SHORT grace, then stop instead
# of burning the full idle budget).
# Derive from the COUNT of Copilot reviews (any commit), NOT from copilot_latest_commit: a review
# can carry a null/empty commit_id (e.g. after a force-push orphans the reviewed commit, or for
# certain bot summary reviews), and keying off the commit would then report reviewed-any=0 while a
# review genuinely exists — wrongly routing the loop into the full-patience wait. Counting reviews
# is independent of commit_id.
copilot_review_count=$(printf '%s' "$reviews_raw" \
  | jq --arg re "$COPILOT_LOGIN_RE" \
    '[.[] | select((.user.login // "") | ascii_downcase | test($re))
          | select((.state // "") | test("APPROVED|CHANGES_REQUESTED|COMMENTED"))] | length' \
    2>/dev/null || echo 0)
case "$copilot_review_count" in (''|*[!0-9]*) copilot_review_count=0 ;; esac
copilot_reviewed_any=0
[ "$copilot_review_count" -gt 0 ] && copilot_reviewed_any=1

copilot_reviewed_head=0
copilot_changes_requested=0
if [ -n "$copilot_latest_commit" ] && [ -n "$head_oid" ] && [ "$copilot_latest_commit" = "$head_oid" ]; then
  copilot_reviewed_head=1
  if [ "$copilot_latest_state" = "CHANGES_REQUESTED" ]; then copilot_changes_requested=1; fi
fi

# ── Unresolved Copilot review threads (inline comments) ─────────────────────
Q='query($o:String!,$r:String!,$n:Int!,$endCursor:String){repository(owner:$o,name:$r){pullRequest(number:$n){reviewThreads(first:100,after:$endCursor){pageInfo{hasNextPage endCursor}nodes{id isResolved comments(first:100){nodes{databaseId path line originalLine body author{login}}}}}}}}'
JQ='.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false) | .id as $t | .comments.nodes[] | {id: .databaseId, path, line: (.line // .originalLine), author: (.author.login // "ghost"), body, thread: $t}'

all=$(gh api graphql --paginate -f query="$Q" -F o="$OWNER" -F r="$REPO" -F n="$PR_NUM" --jq "$JQ" 2>/dev/null || true)
copilot=$(printf '%s\n' "$all" | jq -c --arg re "$COPILOT_LOGIN_RE" 'select((.author | ascii_downcase) | test($re))' 2>/dev/null || true)
# Count distinct unresolved threads (not raw comment lines) so the progress number
# reflects thread count even when a thread has multiple Copilot comments.
unresolved=$(printf '%s' "$copilot" | jq -rs '[.[].thread] | unique | length' 2>/dev/null || printf '%s' "$copilot" | grep -c . || true)

# ── Status checks ────────────────────────────────────────────────────────────
# --required limits to checks required by branch-protection rules so optional
# or flaky checks cannot wedge the loop. Best-effort — zeros on failure.
checks=$(gh pr checks "$PR_NUM" --required --json bucket 2>/dev/null || echo '[]')
pending=$(printf '%s' "$checks" | jq '[.[]|select(.bucket=="pending")]|length' 2>/dev/null || echo 0)
failing=$(printf '%s' "$checks" | jq '[.[]|select(.bucket=="fail" or .bucket=="cancel")]|length' 2>/dev/null || echo 0)
passing=$(printf '%s' "$checks" | jq '[.[]|select(.bucket=="pass")]|length' 2>/dev/null || echo 0)

if [ -n "$OUT" ]; then
  mkdir -p "$(dirname "$OUT")"
  printf '%s\n' "$copilot" > "$OUT"
fi
echo "loop-status: copilot-reviewed-head=$copilot_reviewed_head copilot-changes-requested=$copilot_changes_requested copilot-pending=$copilot_pending unresolved-copilot=$unresolved checks-pending=$pending checks-failing=$failing checks-passing=$passing copilot-reviewed-any=$copilot_reviewed_any"
exit 0
