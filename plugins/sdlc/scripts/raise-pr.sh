#!/usr/bin/env bash
set -euo pipefail
# raise-pr.sh [--phase <p>] <head> <base> <title> <body_file> [reviewer]
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
#
# OPTIONAL `--phase <p>` flag (p ∈ {spec,plan,impl}): passed through to
# read-review-config.sh so the per-repo "Review gate" can downgrade this phase's
# effective REVIEW_MODE to `none` (skip the reviewer request) when the phase is
# not gated. It is parsed and stripped BEFORE the positional args, so the
# positional contract <head> <base> <title> <body_file> [reviewer] is preserved.

# Parse + strip the optional --phase flag first; everything else stays positional.
PHASE=""
ARGS=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --phase) PHASE="${2:-}"; shift 2 ;;
    *)       ARGS+=("$1"); shift ;;
  esac
done
set -- "${ARGS[@]}"

HEAD="${1:?head branch required}"
BASE="${2:?base branch required}"
TITLE="${3:?title required}"
BODY_FILE="${4:?body file required}"
REVIEWER="${5:-@copilot}"

# Review config (per-repo) from .claude/project/project-context.md, via the shared reader so the
# token regex + defaults live in one place (see read-review-config.sh):
#   REVIEW_AGENT : github-copilot (default) | claude-inline
#   REVIEW_MODE  : none | on-create | on-update (default)
# - REVIEW_MODE=none      ⇒ no review gate — skip the reviewer request entirely.
# - REVIEW_AGENT=claude-inline ⇒ the review runs in-session via /code-review during the /loop;
#   there is NO bot to assign here, so skip the reviewer request (the loop owns the review).
# - REVIEW_AGENT=github-copilot ⇒ request the bot here at creation, exactly as before (back-compat).
# When --phase was passed, thread it through so the per-repo Review gate can downgrade THIS phase's
# effective REVIEW_MODE to `none` (the same reviewer-skip path) when the phase is not gated.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -n "$PHASE" ]; then
  eval "$(bash "$SCRIPT_DIR/read-review-config.sh" --phase "$PHASE" || true)"
else
  eval "$(bash "$SCRIPT_DIR/read-review-config.sh" || true)"
fi
# Belt-and-suspenders: if the reader is missing/unreadable the eval sets nothing, and under
# `set -u` the next REVIEW_MODE/REVIEW_AGENT read would abort the script AFTER the PR was already
# created — breaking this file's "best-effort, NEVER fails PR creation" contract. Default both here
# so a reader failure degrades to the safe github-copilot/on-update path instead of crashing.
REVIEW_AGENT="${REVIEW_AGENT:-github-copilot}"
REVIEW_MODE="${REVIEW_MODE:-on-update}"

[ -f "$BODY_FILE" ] || { echo "ERROR: body file not found: $BODY_FILE" >&2; exit 1; }

# 1. Create the PR — or reuse an existing open one for this head (idempotent re-run).
PR_URL=$(gh pr create --title "$TITLE" --body-file "$BODY_FILE" --base "$BASE" --head "$HEAD" 2>/dev/null) \
  || PR_URL=$(gh pr view "$HEAD" --json url -q .url 2>/dev/null || true)
[ -n "$PR_URL" ] || { echo "ERROR: could not create or locate a PR for head=$HEAD" >&2; exit 1; }
echo "pr-open: $PR_URL" >&2

# 2. Mark ready for review (no-op if already non-draft). Best-effort.
gh pr ready "$PR_URL" >/dev/null 2>&1 || echo "warn: gh pr ready failed (already ready?) — continuing" >&2

# Review gate: skip the bot request + verification when there is no bot to request —
# either `none` mode (no review gate) or `claude-inline` agent (the /loop runs /code-review
# in-session instead of assigning a reviewer). Only github-copilot requests the bot here.
if [ "$REVIEW_MODE" = "none" ]; then
  if [ -n "$PHASE" ]; then
    echo "review-gate: phase '$PHASE' not gated (effective review-mode=none) — not requesting $REVIEWER" >&2
  else
    echo "review-mode=none — not requesting $REVIEWER (no review gate)" >&2
  fi
elif [ "$REVIEW_AGENT" = "claude-inline" ]; then
  echo "review-agent=claude-inline — not requesting $REVIEWER (review runs in-session via /code-review during the loop)" >&2
else
# 3. Request the review bot. Best-effort — NEVER fail the PR on this.
gh pr edit "$PR_URL" --add-reviewer "$REVIEWER" >/dev/null 2>&1 \
  || echo "warn: 'gh pr edit --add-reviewer $REVIEWER' returned non-zero (gh<2.88.0 or bot unavailable)" >&2

# 4. VERIFY the request actually attached. `gh pr edit --add-reviewer` can exit 0 yet silently
#    drop a Bot reviewer, and `gh pr view --json reviewRequests` does NOT list Bot reviewers — so
#    confirm via REST. Distinguish three outcomes so a slug/API failure is never reported as a
#    missing reviewer: (a) verified present, (b) verified absent, (c) could-not-verify.
SLUG=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
PR_NUM="${PR_URL##*/}"
if [ -z "$SLUG" ]; then
  echo "warn: could not determine repo slug — $REVIEWER request NOT verified (PR created regardless)" >&2
elif reviewers=$(gh api "repos/$SLUG/pulls/$PR_NUM/requested_reviewers" --jq '.users[].login' 2>/dev/null); then
  # gh api succeeded — empty output here means the reviewer is genuinely absent.
  if printf '%s\n' "$reviewers" | grep -qix "${REVIEWER#@}"; then
    echo "reviewer-confirmed: $REVIEWER requested on $PR_URL" >&2
  else
    echo "warn: $REVIEWER NOT present in requested_reviewers for $PR_URL — assign it manually" >&2
  fi
else
  # gh api itself failed (auth/network/404) — verification could not run; do not claim absence.
  echo "warn: could not query requested_reviewers (auth/network) — $REVIEWER request NOT verified" >&2
fi
fi  # end review-mode gate

# 5. Bare URL to stdout for capture by the caller.
printf '%s\n' "$PR_URL"
