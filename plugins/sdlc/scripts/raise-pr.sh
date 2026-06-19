#!/usr/bin/env bash
set -euo pipefail
# raise-pr.sh <head> <base> <title> <body_file> [reviewer]
#
# Atomically opens the implementation PR and wires up review, so the three steps that must
# always happen together — create, mark-ready, request the review bot — cannot be half-done
# by a caller that hand-rolls `gh pr create` and forgets the rest.
#
# Why a script: the create -> ready -> add-reviewer -> verify sequence (with its REST
# verification of a Bot-type reviewer that `gh pr view --json reviewRequests` cannot see) is
# exactly the kind of multi-step gh logic that gets dropped when typed inline. Centralising it
# here means every PR is opened the same way, and the auto-mode allowlist
# (`Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/*)`) matches a single invocation. Body text is
# passed BY FILE (never inline), per the shell-safety rules.
#
# Args:
#   $1 head        feature branch to open the PR from (e.g. feat/<STORY-KEY>)
#   $2 base        base branch to merge into (e.g. develop)
#   $3 title       PR title (e.g. "[<STORY-KEY>] <summary>")
#   $4 body_file   path to a markdown file holding the PR body
#   $5 reviewer    OPTIONAL review handle to request (default: @copilot)
#
# Output:
#   - The bare PR URL is the ONLY thing printed to stdout, so callers can capture it:
#       PR_URL=$(bash raise-pr.sh feat/KEY develop "[KEY] title" "$dir/pr-body.md")
#   - All progress / warnings go to stderr.
#
# Idempotent: re-running for a head branch that already has an open PR reuses it.
# Reviewer assignment is best-effort and NEVER fails PR creation.

HEAD="${1:?head branch required}"
BASE="${2:?base branch required}"
TITLE="${3:?title required}"
BODY_FILE="${4:?body file required}"
REVIEWER="${5:-@copilot}"

[ -f "$BODY_FILE" ] || { echo "ERROR: body file not found: $BODY_FILE" >&2; exit 1; }

# 1. Create the PR — or reuse an existing open one for this head (idempotent re-run).
PR_URL=$(gh pr create --title "$TITLE" --body-file "$BODY_FILE" --base "$BASE" --head "$HEAD" 2>/dev/null) \
  || PR_URL=$(gh pr view "$HEAD" --json url -q .url 2>/dev/null || true)
[ -n "$PR_URL" ] || { echo "ERROR: could not create or locate a PR for head=$HEAD" >&2; exit 1; }
echo "pr-open: $PR_URL" >&2

# 2. Mark ready for review (no-op if already non-draft). Best-effort.
gh pr ready "$PR_URL" >/dev/null 2>&1 || echo "warn: gh pr ready failed (already ready?) — continuing" >&2

# 3. Request the review bot. Best-effort — NEVER fail the PR on this.
gh pr edit "$PR_URL" --add-reviewer "$REVIEWER" >/dev/null 2>&1 \
  || echo "warn: 'gh pr edit --add-reviewer $REVIEWER' returned non-zero (gh<2.88.0 or bot unavailable)" >&2

# 4. VERIFY the request actually attached. `gh pr edit --add-reviewer` can exit 0 yet silently
#    drop a Bot reviewer, and `gh pr view --json reviewRequests` does NOT list Bot reviewers — so
#    confirm via REST. Warn loudly (but still succeed) when the bot is missing.
SLUG=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
PR_NUM="${PR_URL##*/}"
if [ -n "$SLUG" ] && gh api "repos/$SLUG/pulls/$PR_NUM/requested_reviewers" \
     --jq '.users[].login' 2>/dev/null | grep -qix "${REVIEWER#@}"; then
  echo "reviewer-confirmed: $REVIEWER requested on $PR_URL" >&2
else
  echo "warn: $REVIEWER NOT present in requested_reviewers for $PR_URL — assign it manually" >&2
fi

# 5. Bare URL to stdout for capture by the caller.
printf '%s\n' "$PR_URL"
