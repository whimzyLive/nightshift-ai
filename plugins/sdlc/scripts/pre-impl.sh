#!/usr/bin/env bash
set -uo pipefail
# pre-impl.sh <STORY-KEY> <BRANCH_PREFIX> <BASE-BRANCH> <LIGHTWEIGHT>
#
# Principal Engineer playbook Steps 1, 2.5 and 3 in ONE call: task-source check (full path),
# BASE_SHA, existing-PR check, dependency gate, sub-task probe, worktree provision, branch push.
# Each step used to be its own orchestrator turn; every turn re-reads the whole orchestrator
# context, so folding them into one call is the saving. Run from the primary checkout.
#
# Output (greppable; stops at the first failing step):
#   RESULT=ok | RESULT=stop with REASON=<why>     always the LAST line; exit 0 ok / 1 stop
#   BASE_SHA=<sha of origin/<BASE-BRANCH>>   (the QA review-range start; a pre-existing branch has
#            the base merged in first, so BASE_SHA..HEAD is exactly the story's own work)
#   PR_STATE=none|open                        open -> the PR is reused
#   UI_BLOCKERS=<keys or empty>                               from dep-gate.sh
#   SUBTASK_COUNT=<n> then one `SUBTASK=<key><TAB><summary>` line each, in Jira created order
#   WORKTREE=<abs path>  NX_CACHE_DIRECTORY=<abs path>        from worktree-setup.sh

here="$(cd "$(dirname "$0")" && pwd)"
KEY="${1:?usage: pre-impl.sh <STORY-KEY> <BRANCH_PREFIX> <BASE-BRANCH> <LIGHTWEIGHT>}"
PREFIX="${2:?branch prefix required}"
BASE="${3:?base branch required}"
LIGHTWEIGHT="${4:-false}"
BRANCH="$PREFIX/$KEY"

stop() { echo "REASON=$1"; echo "RESULT=stop"; exit 1; }

# 1. Does the story branch already exist on origin (e.g. /spec committed the approved spec)?
branch_existed=false
if git ls-remote --exit-code --heads origin "$BRANCH" >/dev/null 2>&1; then
  branch_existed=true
  git fetch -q origin "$BRANCH" || stop "git fetch origin $BRANCH failed"
fi
git fetch -q origin "$BASE" || stop "git fetch origin $BASE failed"

# 2. Full path: a task source — a legacy spec merged to the base branch or a legacy plan doc, or
#    the spec on the story branch, which also needs its Spec-Approved label (removed on any edit).
if [ "$LIGHTWEIGHT" != "true" ]; then
  if git cat-file -e "origin/$BASE:docs/superpowers/specs/$KEY.md" 2>/dev/null \
    || test -f "docs/superpowers/plans/$KEY.md"; then
    :
  elif [ "$branch_existed" = true ] && git cat-file -e "origin/$BRANCH:docs/superpowers/specs/$KEY.md" 2>/dev/null; then
    approved="$(bash "$here/assess-ready.sh" "$KEY" 2>/dev/null | sed -n 's/^SPEC_APPROVED=//p')"
    case "$approved" in
      yes) : ;;
      no) stop "the spec on $BRANCH is not approved (no Spec-Approved label) — run /spec $KEY" ;;
      *) stop "cannot read the Spec-Approved label on $KEY (Jira probe failed)" ;;
    esac
  else
    stop "no approved spec — run /spec $KEY first"
  fi
fi

base_sha="$(git rev-parse "origin/$BASE")" || stop "cannot resolve origin/$BASE"
echo "BASE_SHA=$base_sha"

# 3. Existing implementation PR.
prs="$(gh pr list --head "$BRANCH" --state all --json state 2>/dev/null)" || stop "gh pr list failed for $BRANCH"
if printf '%s' "$prs" | jq -e 'any(.[]; .state == "MERGED")' >/dev/null 2>&1; then
  stop "$BRANCH already has a merged PR — the story is already implemented"
elif printf '%s' "$prs" | jq -e 'any(.[]; .state == "OPEN")' >/dev/null 2>&1; then
  pr_state=open
else
  pr_state=none
fi
echo "PR_STATE=$pr_state"

# 4. Dependency gate.
gate_out="$(bash "$here/dep-gate.sh" "$KEY")"
gate_rc=$?
ui="$(printf '%s\n' "$gate_out" | sed -n 's/^UI_BLOCKERS=//p' | tail -1)"
echo "UI_BLOCKERS=$ui"
if [ "$gate_rc" -ne 0 ]; then
  printf '%s\n' "$gate_out" | grep -E '^(BLOCKERS=|[A-Z][A-Z0-9]*-[0-9]+ PR: )' || true
  stop "dependency gate: $(printf '%s\n' "$gate_out" | sed -n 's/^REASON=//p' | head -1)"
fi

# 5. Sub-tasks, in Jira created order (an empty result is "none", not an error).
bash "$here/jira-site-guard.sh" >/dev/null 2>&1 || stop "jira-site-guard failed before the sub-task probe"
subs="$(acli jira workitem search --jql "parent = $KEY AND issuetype in subTaskIssueTypes() ORDER BY created ASC" \
          --fields "key,summary" --json 2>/dev/null)" || stop "sub-task probe failed (acli)"
printf '%s' "$subs" | jq -e 'type == "array"' >/dev/null 2>&1 || stop "sub-task probe returned unparseable output"
echo "SUBTASK_COUNT=$(printf '%s' "$subs" | jq 'length')"
printf '%s' "$subs" | jq -r '.[] | "SUBTASK=\(.key)\t\(.fields.summary // .summary // "")"'

# 6. Worktree + branch (created inside the worktree; the primary never checks it out).
setup_out="$(bash "$here/worktree-setup.sh" "$KEY" "$BRANCH" "$BASE")" || stop "worktree-setup.sh failed — see stderr"
wt="$(printf '%s\n' "$setup_out" | sed -n 's/^WORKTREE=//p')"
[ -n "$wt" ] || stop "worktree-setup.sh printed no WORKTREE="
printf '%s\n' "$setup_out" | grep -E '^(WORKTREE|NX_CACHE_DIRECTORY)='

# 7. A pre-existing branch is brought up to date with the base: it may predate a UI-Components
#    merge, and BASE_SHA..HEAD must not show base commits as reverse changes.
if [ "$branch_existed" = true ]; then
  git -C "$wt" merge -q --no-edit "origin/$BASE" >/dev/null 2>&1 \
    || { git -C "$wt" merge --abort >/dev/null 2>&1; stop "merging origin/$BASE into $BRANCH conflicts — resolve by hand"; }
fi

git -C "$wt" push -q -u origin "$BRANCH" >/dev/null 2>&1 || stop "git push -u origin $BRANCH failed"
echo "RESULT=ok"
