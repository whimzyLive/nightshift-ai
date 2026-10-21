#!/usr/bin/env bash
# Jira dependency gate for the Principal Engineer playbook (Step 1).
# Usage: dep-gate.sh <STORY-KEY>
#   e.g. dep-gate.sh <STORY-KEY>
#
# Resolves the story's parent epic, derives its BLOCKERS by sibling-inversion
# (acli link list only exposes outwardIssueKey = the issue a story BLOCKS, so a
# sibling S blocks STORY iff S's links contain outwardIssueKey == STORY), and
# verifies every blocker already has a feat/<blocker> OR fix/<blocker> PR (open or merged).
# A blocker labelled UI-Components needs a MERGED PR: the dependent branch is cut from the
# base branch and must already contain the components (refs/ui-components.md).
#
# All command substitution / loops / jq live INSIDE this script so the caller
# issues one statically-analyzable invocation (allowlisted Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/*)).
#
# Output (greppable, deterministic):
#   EPIC=<key>
#   BLOCKERS=<space-separated keys or empty>
#   <blocker> PR: yes|NO|unmerged (one line per blocker; unmerged = UI-Components blocker without a merged PR)
#   UI_BLOCKERS=<keys or empty>  UI-Components blockers; the branch must contain their merge
#   GATE=PASS                   -> exit 0, safe to implement
#   GATE=STOP                   -> exit 1, with REASON= line(s)
#
# acli is the only source of truth — any acli query error => GATE=STOP (cannot verify).
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"

story="${1:?usage: dep-gate.sh <STORY-KEY>}"

fail() { echo "REASON=$1"; echo "GATE=STOP"; exit 1; }

guard_err="$(bash "$here/jira-site-guard.sh" 2>&1)" || fail "jira-site-guard: ${guard_err:-unknown failure (re-run: bash $here/jira-site-guard.sh)}"

# 1. Parent epic — MUST pass --fields parent; the default view strips it (returns null).
epic="$(acli jira workitem view "$story" --fields parent --json 2>/dev/null \
          | jq -r '.fields.parent.key // empty')"
[ -z "$epic" ] && fail "cannot resolve parent epic for $story (acli view --fields parent returned empty)"
echo "EPIC=$epic"

# 2. Siblings = all children of the epic.
siblings="$(acli jira workitem search --jql "parent = $epic" --json 2>/dev/null \
              | jq -r '.[].key')"
[ -z "$siblings" ] && fail "could not list children of $epic (cannot verify dependencies)"

# 3. Inversion: a sibling S blocks $story iff S's links have outwardIssueKey == $story.
blockers=""
while IFS= read -r s; do
  [ -z "$s" ] && continue
  [ "$s" = "$story" ] && continue
  if acli jira workitem link list --key "$s" --json 2>/dev/null \
       | jq -e --arg k "$story" \
         '.issueLinks[]? | select(.typeName=="Blocks" and .outwardIssueKey==$k)' >/dev/null; then
    blockers="${blockers:+$blockers }$s"
  fi
done <<< "$siblings"
echo "BLOCKERS=$blockers"

# 4. Every blocker must already have a feat/<blocker> OR fix/<blocker> PR (open or merged).
#    Dual-prefix: a blocker that shipped as a defect lives on fix/<blocker>, not feat/<blocker>.
#    Two EXACT --head lookups (pass if EITHER yields >=1 PR). Keep exact --head semantics — do NOT
#    use `gh pr list --search`: it ignores --state (express state in-query) and its head: qualifier
#    is a substring/ref match, not the exact branch match --head gives; either pitfall silently
#    corrupts the gate. The doubled round-trip (2 exact calls per blocker) is acceptable.
#    Both-present (a stale opposite-prefix PR for an abandoned attempt) is a LEGAL state, not a
#    contradiction — never assert/error on "two matches"; pass if either prefix has a PR.
rc=0
unmerged=""
ui_blockers=""
for dep in $blockers; do
  ui_json="$(acli jira workitem search --jql "key = $dep AND labels = \"UI-Components\"" --fields key --json 2>/dev/null)" \
    || fail "cannot read labels of blocker $dep (cannot verify dependencies)"
  ui="$(printf '%s' "$ui_json" | jq --arg k "$dep" '[.[]? | select(.key == $k)] | length' 2>/dev/null)"
  [ -z "$ui" ] && fail "cannot read labels of blocker $dep (cannot verify dependencies)"
  feat_found="$(gh pr list --head "feat/$dep" --state all --json number 2>/dev/null | jq 'length')"
  fix_found="$(gh pr list --head "fix/$dep"  --state all --json number 2>/dev/null | jq 'length')"
  if [ "${feat_found:-0}" -eq 0 ] && [ "${fix_found:-0}" -eq 0 ]; then
    echo "$dep PR: NO"
    rc=1
    continue
  fi
  if [ "$ui" -gt 0 ]; then
    ui_blockers="${ui_blockers:+$ui_blockers }$dep"
    feat_merged="$(gh pr list --head "feat/$dep" --state merged --json number 2>/dev/null | jq 'length')"
    fix_merged="$(gh pr list --head "fix/$dep"  --state merged --json number 2>/dev/null | jq 'length')"
    if [ "${feat_merged:-0}" -eq 0 ] && [ "${fix_merged:-0}" -eq 0 ]; then
      echo "$dep PR: unmerged"
      unmerged="${unmerged:+$unmerged }$dep"
      continue
    fi
  fi
  echo "$dep PR: yes"
done
echo "UI_BLOCKERS=$ui_blockers"

if [ "$rc" -ne 0 ]; then
  echo "REASON=one or more blockers have no feat/* or fix/* PR — implement the blocker first (or remove a stale Jira Blocks link)"
fi
if [ -n "$unmerged" ]; then
  echo "REASON=UI-Components blocker(s) $unmerged not merged — merge the components PR first; this branch is cut from the base branch"
  rc=1
fi
if [ "$rc" -ne 0 ]; then
  echo "GATE=STOP"
  exit 1
fi

echo "GATE=PASS"
