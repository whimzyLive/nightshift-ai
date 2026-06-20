#!/usr/bin/env bash
set -euo pipefail
# auto-merge-pr.sh <pr>
#
# Merge a pull request using the repository's allowed merge method, resolved DYNAMICALLY at
# merge time — never a hard-coded flag. Used by /auto's Full-Auto terminal action, after the
# review-fix loop has driven the PR to a clean state (Copilot approved on the reviewed head +
# checks green). Merging emits the GitHub `pull_request closed+merged` event that the automation
# service consumes to advance the pipeline.
#
# Why a script: the resolve-method -> merge -> verify sequence is multi-step gh logic that gets
# dropped or mis-flagged when typed inline, and a bare `gh pr merge` prompts interactively for the
# method when a repo allows more than one — which would hang an automated session. Centralising it
# means the auto-mode allowlist (`Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/*)`) matches a single
# invocation, and the explicit resolved flag is always passed.
#
# Method resolution precedence (first enabled wins): merge-commit -> squash -> rebase. The repo's
# own settings govern; if a repo disables a method this is honored with no script change. If NO
# method is enabled, or the merge does not take, the script exits non-zero so the caller (/auto)
# halts and surfaces — it must NOT guess, and the PR stays open.
#
# Args:
#   $1 pr   PR number or URL to merge
#
# Output:
#   - On success: prints `MERGED` to stdout; progress/warnings go to stderr.
#   - On failure: non-zero exit, reason on stderr, nothing on stdout.

PR="${1:?PR number or URL required}"

SLUG=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
[ -n "$SLUG" ] || { echo "ERROR: could not determine repo slug (gh repo context)" >&2; exit 1; }

# Resolve the merge method from the repo's allowed methods (precedence: merge-commit > squash > rebase).
METHOD=$(gh api "repos/$SLUG" \
  --jq 'if .allow_merge_commit then "--merge" elif .allow_squash_merge then "--squash" elif .allow_rebase_merge then "--rebase" else "" end' \
  2>/dev/null || true)
[ -n "$METHOD" ] || { echo "ERROR: no merge method enabled on $SLUG — cannot auto-merge" >&2; exit 1; }
echo "auto-merge: $SLUG PR $PR using $METHOD" >&2

# Merge with the explicit resolved flag (never a bare `gh pr merge` — that prompts interactively).
gh pr merge "$PR" "$METHOD" >/dev/null 2>&1 \
  || { echo "ERROR: gh pr merge $PR $METHOD failed (branch protection / conflict / required checks not met)" >&2; exit 1; }

# Verify it actually merged — `gh pr merge` can exit 0 with auto-merge queued but not yet applied.
STATE=$(gh pr view "$PR" --json state -q .state 2>/dev/null || true)
[ "$STATE" = "MERGED" ] || { echo "ERROR: PR $PR not MERGED after merge call (state=${STATE:-unknown})" >&2; exit 1; }
echo "merged: PR $PR" >&2

printf 'MERGED\n'
