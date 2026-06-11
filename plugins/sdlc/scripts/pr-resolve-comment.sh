#!/usr/bin/env bash
set -euo pipefail
# pr-resolve-comment.sh <pr> <comment_database_id> <accepted|rejected> <body_file>
#
# Posts a justification reply on a single GitHub PR *inline review comment* thread,
# then — only when the decision is `accepted` — RESOLVES that review thread so it
# disappears from the reviewer's open list. Rejected comments are replied to but
# left OPEN, so the reviewer sees only unresolved items, each with a rationale.
#
# Why a script: the resolve step needs the GraphQL `resolveReviewThread` mutation
# (REST cannot resolve threads) + a databaseId→threadId lookup. That $()/jq/GraphQL
# logic can't be statically analyzed on a Bash command line — it lives here so the
# auto-mode allowlist (`Bash(bash ./${CLAUDE_PLUGIN_ROOT}/scripts/*)`) matches. Body text is passed
# BY FILE (never inline JSON), per the repo's shell-safety rules.
#
# Args:
#   $1 pr            PR number
#   $2 comment id    the REST `id` (databaseId) of the inline review comment
#   $3 decision      accepted | rejected
#   $4 body_file     path to a markdown file with the reply text (justification)
#
# Prints one greppable status line. Never fails the caller on a resolve miss
# (reply already posted) — exits 0 with a warn.

PR="$1"; CID="$2"; DECISION="$3"; BODY_FILE="$4"

[ -f "$BODY_FILE" ] || { echo "ERROR: body file not found: $BODY_FILE" >&2; exit 1; }
case "$DECISION" in accepted|rejected) ;; *) echo "ERROR: decision must be accepted|rejected" >&2; exit 1;; esac

SLUG=$(gh repo view --json nameWithOwner -q .nameWithOwner)
OWNER="${SLUG%/*}"; REPO="${SLUG#*/}"

# 1. Reply in the comment's review thread (REST works for inline review comments).
gh api -X POST "repos/$OWNER/$REPO/pulls/$PR/comments/$CID/replies" -F body=@"$BODY_FILE" >/dev/null \
  && echo "replied: comment=$CID decision=$DECISION"

# 2. Rejected → leave the thread OPEN so the reviewer still sees it.
[ "$DECISION" = "accepted" ] || { echo "left-open: comment=$CID (rejected)"; exit 0; }

# 3. Accepted → find the review-thread node id holding this comment, then resolve it.
TQ='query($o:String!,$r:String!,$n:Int!){repository(owner:$o,name:$r){pullRequest(number:$n){reviewThreads(first:100){nodes{id comments(first:50){nodes{databaseId}}}}}}}'
THREAD_ID=$(gh api graphql -f query="$TQ" -F o="$OWNER" -F r="$REPO" -F n="$PR" \
  --jq "[.data.repository.pullRequest.reviewThreads.nodes[] | select(any(.comments.nodes[]; .databaseId == $CID)) | .id] | first // empty")

[ -n "$THREAD_ID" ] || { echo "warn: no review thread for comment=$CID — reply posted, NOT resolved"; exit 0; }

MQ='mutation($t:ID!){resolveReviewThread(input:{threadId:$t}){thread{isResolved}}}'
gh api graphql -f query="$MQ" -F t="$THREAD_ID" --jq '.data.resolveReviewThread.thread.isResolved' >/dev/null \
  && echo "resolved: comment=$CID thread=$THREAD_ID"
