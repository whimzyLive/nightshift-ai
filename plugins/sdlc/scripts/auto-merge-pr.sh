#!/usr/bin/env bash
set -euo pipefail
# auto-merge-pr.sh [--auto] <pr> [<story-key> <done-status>]
#
# Merge a pull request using the repository's allowed merge method, resolved DYNAMICALLY at
# merge time — never a hard-coded flag. Used by /auto's Full-Auto terminal action. Two modes:
#   - default (no --auto): an IMMEDIATE merge. Used by A2/B1, where the caller has already driven
#     the PR to a clean, checks-green state first (the review-fix loop).
#   - `--auto`: ENABLES GitHub's native auto-merge on the PR and returns as soon as it is queued,
#     without waiting for checks. Used by A1's spec PR (NA-104), which never enters the
#     review-fix loop and so has no prior guarantee the PR is already mergeable — attempting an
#     immediate merge there would race the CI run `raise-pr.sh` just triggered. GitHub itself
#     completes the merge once required checks turn green and the PR is mergeable.
# Either way, merging emits the GitHub `pull_request closed+merged` event that the automation
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
# method is enabled, or the merge (or auto-merge enable) does not take, the script exits non-zero
# so the caller (/auto) halts and surfaces — it must NOT guess, and the PR stays open.
#
# Args:
#   --auto          OPTIONAL, must be the FIRST argument when present (see modes above). Parsed
#                   and stripped before the positional args below, so their order is unchanged.
#   $1 pr           PR number or URL to merge
#   $2 story-key    OPTIONAL — the Jira story key to transition after a story-COMPLETING merge
#                   (Workflow B impl PR, or Workflow A Phase-2 plan+impl PR). Omit for a
#                   non-completing merge (e.g. Workflow A Phase-1 spec PR) — the story stays
#                   in progress and no transition is attempted. Not used with `--auto` — the
#                   merge hasn't happened yet when this script returns, so there is nothing to
#                   transition; A1 never passes these.
#   $3 done-status  OPTIONAL — the consuming project's pipeline done status (e.g. `Done`), read
#                   by the caller from `.claude/project/project-context.md`'s `Pipeline done
#                   status` token. Both $2 and $3 must be supplied together to enable the
#                   transition block below; supplying only one is treated as neither (1-arg
#                   behaviour) since a story key with no target status (or vice versa) cannot
#                   drive a transition.
#
# Note: the transition requires the consumer repo's Jira workflow to permit a DIRECT transition
# from the story's current status to <done-status>; a workflow that forces an intermediate hop
# (no direct edge) will hit the best-effort warning path below by design (see AC-5).
#
# Transition semantics (only when both $2 and $3 are supplied, run AFTER a verified MERGED):
#   - Idempotent: if the story's current status already equals <done-status>, this is a no-op
#     (logged to stderr), not an error.
#   - Best-effort: the transition (and its status read) can NEVER fail this script — the merge
#     already succeeded. Any transition failure emits a `WARNING:` to stderr and posts a Jira
#     comment on the story noting the auto-transition failed and a human should move it
#     manually; the script still prints `MERGED` and exits 0.
#
# Back-compat: called with exactly 1 arg (no `--auto`), this script is byte-for-byte behaviourally
# identical to the original merge-only version — no transition block runs, nothing new is printed.
#
# Output:
#   - On success: prints `MERGED` (default mode) or `AUTO-MERGE-ENABLED` (`--auto` mode) to
#     stdout; progress/warnings go to stderr.
#   - On failure: non-zero exit, reason on stderr, nothing on stdout. (The transition block never
#     causes a non-zero exit — see Best-effort above.)

here="$(cd "$(dirname "$0")" && pwd)"

AUTO=false
if [ "${1:-}" = "--auto" ]; then
  AUTO=true
  shift
fi

PR="${1:?PR number or URL required}"
STORY_KEY="${2:-}"
DONE_STATUS="${3:-}"

SLUG=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
[ -n "$SLUG" ] || { echo "ERROR: could not determine repo slug (gh repo context)" >&2; exit 1; }

# Resolve the merge method from the repo's allowed methods (precedence: merge-commit > squash >
# rebase). Distinguish a gh-api failure (auth/network/API) from "no method enabled" — they need
# different fixes, so do NOT swallow the api error with `|| true`. Distinct exit codes: 2 = could
# not query; 1 = queried OK but no method enabled.
if ! METHOD=$(gh api "repos/$SLUG" \
  --jq 'if .allow_merge_commit then "--merge" elif .allow_squash_merge then "--squash" elif .allow_rebase_merge then "--rebase" else "" end'); then
  echo "ERROR: could not query merge settings for $SLUG (gh api auth/network/API failure)" >&2
  exit 2
fi
[ -n "$METHOD" ] || { echo "ERROR: no merge method enabled on $SLUG — cannot auto-merge" >&2; exit 1; }
echo "auto-merge: $SLUG PR $PR using $METHOD" >&2

if [ "$AUTO" = true ]; then
  # --auto mode (A1's spec PR, NA-104): ENABLE GitHub auto-merge and return promptly — do NOT
  # wait for MERGED, which may not happen for minutes/hours (GitHub merges it once required
  # checks turn green and it's mergeable). Skips the Jira-transition block below entirely: the
  # merge hasn't happened yet, so there is nothing to transition here.
  if ! MERGE_OUT=$(gh pr merge "$PR" "$METHOD" --auto 2>&1); then
    echo "ERROR: gh pr merge $PR $METHOD --auto failed (auto-merge disabled on repo / branch protection / conflict): $MERGE_OUT" >&2
    exit 1
  fi
  ENABLED=""
  for _ in 1 2 3; do
    ENABLED=$(gh pr view "$PR" --json autoMergeRequest -q 'if .autoMergeRequest then "yes" else "" end' 2>/dev/null || true)
    [ "$ENABLED" = "yes" ] && break
    sleep 2
  done
  [ "$ENABLED" = "yes" ] || { echo "ERROR: PR $PR auto-merge not confirmed enabled after gh pr merge --auto; merge output: $MERGE_OUT" >&2; exit 1; }
  echo "auto-merge-enabled: PR $PR (GitHub will merge it once checks pass)" >&2
  printf 'AUTO-MERGE-ENABLED\n'
  exit 0
fi

# Merge with the explicit resolved flag. `gh pr merge` only prompts interactively for the merge
# METHOD when the repo allows more than one and none is given on the command line — passing the
# resolved METHOD explicitly already makes this non-interactive in a TTY-less automated session,
# so no extra confirmation flag is needed. (`--yes` used to be passed here for the same purpose,
# but gh removed the flag — passing it now fails with "unknown flag: --yes".) Capture output for
# diagnostics rather than discarding it.
if ! MERGE_OUT=$(gh pr merge "$PR" "$METHOD" 2>&1); then
  echo "ERROR: gh pr merge $PR $METHOD failed (branch protection / conflict / required checks not met): $MERGE_OUT" >&2
  exit 1
fi

# Verify it actually merged. `gh pr merge` can exit 0 with the merge queued but not yet applied
# (propagation lag, or auto-merge was enabled) — so poll for MERGED over a short bounded window
# (~12s) instead of a single immediate check that can flake.
STATE=""
for _ in 1 2 3 4 5 6; do
  STATE=$(gh pr view "$PR" --json state -q .state 2>/dev/null || echo "")
  if [ "$STATE" = "MERGED" ]; then break; fi
  sleep 2
done
[ "$STATE" = "MERGED" ] || { echo "ERROR: PR $PR not MERGED after merge (state=${STATE:-unknown}); merge output: $MERGE_OUT" >&2; exit 1; }
echo "merged: PR $PR" >&2

# Best-effort, idempotent Jira transition to the pipeline done status (AC-1,2,4,5) — runs ONLY
# when the caller supplied both $2 and $3 (a story-COMPLETING merge on a Full-Auto story; see the
# header docstring). Everything in this block is guarded so a non-zero acli can NEVER abort the
# script under `set -euo pipefail` — the merge above already succeeded, and that must stand
# regardless of transition outcome.
if [ -n "$STORY_KEY" ] && [ -n "$DONE_STATUS" ]; then
  if ! bash "$here/jira-site-guard.sh"; then
    echo "WARNING: jira-site-guard failed for $STORY_KEY — skipping the Jira transition; a human must move it to $DONE_STATUS manually" >&2
  else
    CURRENT_STATUS=$(acli jira workitem view "$STORY_KEY" --fields status --json 2>/dev/null \
                        | jq -r '.fields.status.name // empty' 2>/dev/null || true)
    if [ "$CURRENT_STATUS" = "$DONE_STATUS" ]; then
      echo "transition: $STORY_KEY already $DONE_STATUS — no-op" >&2
    elif acli jira workitem transition --key "$STORY_KEY" --status "$DONE_STATUS" --yes >/dev/null 2>&1; then
      echo "transition: $STORY_KEY -> $DONE_STATUS" >&2
    else
      # Transition call failed — before warning, re-read status: a flaky first read or a
      # concurrent transition may mean the story is ALREADY done, in which case this is an
      # idempotent no-op, not a failure (never post a contradictory "move it manually" comment
      # on a story that's actually already Done).
      RECHECK_STATUS=$(acli jira workitem view "$STORY_KEY" --fields status --json 2>/dev/null \
                          | jq -r '.fields.status.name // empty' 2>/dev/null || true)
      if [ "$RECHECK_STATUS" = "$DONE_STATUS" ]; then
        echo "transition: $STORY_KEY already $DONE_STATUS (confirmed on re-read) — no-op" >&2
      else
        echo "WARNING: auto-transition of $STORY_KEY to $DONE_STATUS failed after merge (permission / workflow-scheme mismatch / status name unavailable) — a human must move it manually" >&2
        acli jira workitem comment create --key "$STORY_KEY" \
          --body "Auto-transition to $DONE_STATUS failed after the PR merged. Please move this story to $DONE_STATUS manually." \
          >/dev/null 2>&1 || echo "WARNING: could not post the auto-transition-failed comment on $STORY_KEY either" >&2
      fi
    fi
  fi
elif [ -n "$STORY_KEY" ]; then
  # Story key supplied but done-status is empty — a resolvable misconfig (e.g. the caller failed
  # to resolve the `Pipeline done status` token), not the deliberate 1-arg back-compat case. The
  # merge already succeeded, but silently skipping the transition here would leave a completing
  # story stuck in progress with no signal — exactly the bug this script fixes. Warn loudly
  # instead of silently no-op'ing; do not attempt any acli call with an empty target status.
  echo "WARNING: story key ($STORY_KEY) supplied but done-status is empty — skipping the Jira transition; the story may remain in progress. Check the 'Pipeline done status' row in .claude/project/project-context.md." >&2
fi

printf 'MERGED\n'
