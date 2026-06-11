#!/usr/bin/env bash
set -euo pipefail
# pr-unresolved-comments.sh <pr> [out_file]
#
# Emits ONLY the inline review-thread comments that live on an UNRESOLVED thread.
# Already-resolved threads (a reviewer ticked "Resolve", or a prior /review-fix run
# resolved them) are skipped — they need no fixing, so they must never enter triage.
#
# Why a script: the REST endpoint `repos/{o}/{r}/pulls/{n}/comments` returns EVERY
# inline comment with no resolution state. Resolution lives only on the GraphQL
# `reviewThreads.isResolved` flag. That GraphQL + jq + pagination can't be statically
# analyzed on a Bash command line — it lives here so the auto-mode allowlist
# (`Bash(bash ./${CLAUDE_PLUGIN_ROOT}/scripts/*)`) matches. Same pattern as pr-resolve-comment.sh.
#
# Args:
#   $1 pr        PR number
#   $2 out_file  optional path to write the NDJSON to (default: stdout only)
#
# Output: NDJSON, one object per line, for each unresolved-thread inline comment:
#   {"id":<databaseId>,"path":"...","line":<n>,"author":"...","body":"...","thread":"<nodeId>"}
# The `id` is the REST databaseId — the same value pr-resolve-comment.sh takes to
# reply + resolve. Prints a one-line count summary to stderr.

PR="$1"; OUT="${2:-}"

SLUG=$(gh repo view --json nameWithOwner -q .nameWithOwner)
OWNER="${SLUG%/*}"; REPO="${SLUG#*/}"

# $endCursor is auto-injected by `gh api graphql --paginate` (needs pageInfo{hasNextPage endCursor}).
Q='query($o:String!,$r:String!,$n:Int!,$endCursor:String){repository(owner:$o,name:$r){pullRequest(number:$n){reviewThreads(first:100,after:$endCursor){pageInfo{hasNextPage endCursor}nodes{id isResolved comments(first:100){nodes{databaseId path line originalLine body author{login}}}}}}}}'

# Keep only unresolved threads; flatten their comments to NDJSON.
JQ='.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false) | .id as $t | .comments.nodes[] | {id: .databaseId, path, line: (.line // .originalLine), author: (.author.login // "ghost"), body, thread: $t}'

ndjson=$(gh api graphql --paginate -f query="$Q" -F o="$OWNER" -F r="$REPO" -F n="$PR" --jq "$JQ")

count=$(printf '%s' "$ndjson" | grep -c . || true)
if [ -n "$OUT" ]; then
  mkdir -p "$(dirname "$OUT")"
  printf '%s\n' "$ndjson" > "$OUT"
  echo "unresolved-inline-comments: $count (written: $OUT)" >&2
else
  printf '%s\n' "$ndjson"
  echo "unresolved-inline-comments: $count" >&2
fi
