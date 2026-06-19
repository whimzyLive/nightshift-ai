#!/usr/bin/env bash
set -euo pipefail
# pr-loop-status.sh <pr> [out_file]
#
# One-shot status probe for the /loop polling cycle. Prints a single greppable
# line: how many UNRESOLVED inline review threads were authored by Copilot, plus
# the PR's status-check tallies (pending / failing / passing). Optionally writes
# the unresolved Copilot comments as NDJSON to <out_file> (same shape as
# pr-unresolved-comments.sh) so /loop can hand them to /review-fix.
#
# Why a script: GraphQL reviewThreads + checks rollup + jq + pagination cannot be
# statically analyzed on a Bash command line — it lives here so the auto-mode
# allowlist (Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/*)) matches. Best-effort:
# always exits 0; a probe failure prints zeros and is handled by the loop.

PR="$1"; OUT="${2:-}"
SLUG=$(gh repo view --json nameWithOwner -q .nameWithOwner)
OWNER="${SLUG%/*}"; REPO="${SLUG#*/}"
PR_NUM="${PR##*/}"

# Copilot review-bot login(s). GitHub's Copilot reviewer posts as this bot login.
COPILOT_LOGIN_RE='^(copilot-pull-request-reviewer|copilot|copilot-pull-request-reviewer\[bot\])$'

Q='query($o:String!,$r:String!,$n:Int!,$endCursor:String){repository(owner:$o,name:$r){pullRequest(number:$n){reviewThreads(first:100,after:$endCursor){pageInfo{hasNextPage endCursor}nodes{id isResolved comments(first:100){nodes{databaseId path line originalLine body author{login}}}}}}}}'
JQ='.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false) | .id as $t | .comments.nodes[] | {id: .databaseId, path, line: (.line // .originalLine), author: (.author.login // "ghost"), body, thread: $t}'

all=$(gh api graphql --paginate -f query="$Q" -F o="$OWNER" -F r="$REPO" -F n="$PR_NUM" --jq "$JQ" 2>/dev/null || true)
copilot=$(printf '%s\n' "$all" | jq -c --arg re "$COPILOT_LOGIN_RE" 'select((.author | ascii_downcase) | test($re))' 2>/dev/null || true)
# Count distinct unresolved threads (not raw comment lines) so the progress number
# reflects thread count even when a thread has multiple Copilot comments.
unresolved=$(printf '%s' "$copilot" | jq -rs '[.[].thread] | unique | length' 2>/dev/null || printf '%s' "$copilot" | grep -c . || true)

# Status checks: use gh's own bucket normalization (pass|fail|pending|skipping|cancel).
# --required limits to checks that are required by branch-protection rules so optional
# or flaky checks cannot wedge the loop. Best-effort — zeros on failure.
checks=$(gh pr checks "$PR_NUM" --required --json bucket 2>/dev/null || echo '[]')
pending=$(printf '%s' "$checks" | jq '[.[]|select(.bucket=="pending")]|length' 2>/dev/null || echo 0)
failing=$(printf '%s' "$checks" | jq '[.[]|select(.bucket=="fail" or .bucket=="cancel")]|length' 2>/dev/null || echo 0)
passing=$(printf '%s' "$checks" | jq '[.[]|select(.bucket=="pass")]|length' 2>/dev/null || echo 0)

if [ -n "$OUT" ]; then
  mkdir -p "$(dirname "$OUT")"
  printf '%s\n' "$copilot" > "$OUT"
fi
echo "loop-status: unresolved-copilot=$unresolved checks-pending=$pending checks-failing=$failing checks-passing=$passing"
exit 0
