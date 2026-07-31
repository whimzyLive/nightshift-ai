#!/usr/bin/env bash
set -uo pipefail
# resolve-ai-workflow-mode.sh <ISSUE-KEY>
#
# Single shared implementation of the AI-Workflow mode ladder, collapsing the two
# duplicated JQL ladders in commands/auto.md — the single-story `MODE=` resolution
# ("Resolving the working issue's mode") and E0's `epicFallback=` resolution — into one
# script both call sites eval (NA-86 A6).
#
# Invocation:
#   bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve-ai-workflow-mode.sh <ISSUE-KEY>
#   eval "$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve-ai-workflow-mode.sh <ISSUE-KEY>)"
#   # -> sets MODE and MODE_SOURCE in the caller's shell
# Exit 0 means a mode line was emitted — this script never fails loudly; a probe error
# resolves to the safe MODE=""/MODE_SOURCE=none row (rung 5), never a non-zero exit.
#
# Stdout (AiWorkflowModeResult) — two KEY=value lines, eval-able:
#   MODE        in {'Full Auto', 'Auto', 'Assisted', ''}   (''  only when neither field nor label is set)
#   MODE_SOURCE in {'field', 'label', 'default-unreadable', 'none'}
#
# MODE_SOURCE is additive observability only (D9) — no caller may branch on it; it can be
# dropped entirely with no downstream break.
#
# Ladder (byte-for-byte the routing/precedence of the two duplicated ladders this replaces):
#   1. Field "AI Workflow" = "Full Auto"  -> MODE=Full Auto, MODE_SOURCE=field
#   2. Field is not EMPTY                 -> read the real value; empty read -> MODE=Auto,
#      MODE_SOURCE=default-unreadable (set-but-unreadable => safe gated default);
#      non-empty read -> MODE=<value>, MODE_SOURCE=field
#   3. Labels, most conservative first: AI-Workflow:assisted -> Assisted,
#      AI-Workflow:auto -> Auto, AI-Workflow:full-auto -> Full Auto (MODE_SOURCE=label)
#   4. Otherwise -> MODE="", MODE_SOURCE=none
#   5. Any probe error -> lands on the same MODE=""/MODE_SOURCE=none human-merge path.
#      "Full Auto" is the ONLY value that enables auto-merge — a transient read error
#      must never trigger an unattended merge.
#
# rationale: ${CLAUDE_PLUGIN_ROOT}/refs/jira-fetch.md
# The rung-2 "is not EMPTY" probe applies that file's retry discipline: a JQL index can
# lag a just-written field, so a single empty/erroring probe is not proof the field is
# unset. Retry a few times with a short back-off; only a clean, repeatable empty (or a
# persistent error) falls through to the label rungs.

ISSUE_KEY="${1:-}"
if [ -z "$ISSUE_KEY" ]; then
  printf 'MODE=%s\n' ""
  printf 'MODE_SOURCE=%s\n' "none"
  exit 0
fi

# probe_key <jql> -> 0 (matched) | 1 (no match) | 2 (acli errored — inconclusive)
probe_key() {
  local jql="$1" out rc=0
  out="$(acli jira workitem search --jql "$jql" --fields key 2>/dev/null)" || rc=1
  [ "$rc" -eq 0 ] || return 2
  printf '%s' "$out" | grep -qw "$ISSUE_KEY" && return 0
  return 1
}

MODE=""
MODE_SOURCE="none"

if probe_key "key = $ISSUE_KEY AND \"AI Workflow\" = \"Full Auto\""; then
  MODE="Full Auto"
  MODE_SOURCE="field"
else
  # Rung 2, with the jira-fetch.md retry discipline.
  rung2_result=1  # 0=matched (field set) | 1=clean empty | 2=inconclusive (errored every attempt)
  for _attempt in 1 2 3; do
    rc=0
    probe_key "key = $ISSUE_KEY AND \"AI Workflow\" is not EMPTY" || rc=$?
    if [ "$rc" -eq 0 ]; then
      rung2_result=0
      break
    elif [ "$rc" -eq 1 ]; then
      rung2_result=1
      break
    fi
    rung2_result=2
    sleep 2
  done

  if [ "$rung2_result" -eq 0 ]; then
    VALUE="$(acli jira workitem view "$ISSUE_KEY" --fields 'AI Workflow' --json 2>/dev/null \
              | jq -r '.fields["AI Workflow"].value // .fields["AI Workflow"].name // .fields["AI Workflow"] // empty' 2>/dev/null || true)"
    if [ -z "$VALUE" ]; then
      MODE="Auto"
      MODE_SOURCE="default-unreadable"
    else
      MODE="$VALUE"
      MODE_SOURCE="field"
    fi
  fi
  # rung2_result=1 (clean empty) or 2 (inconclusive after retries) both fall through to
  # the label rungs below, same as the original elif chain.

  if [ -z "$MODE" ]; then
    if probe_key "key = $ISSUE_KEY AND labels = \"AI-Workflow:assisted\""; then
      MODE="Assisted"; MODE_SOURCE="label"
    elif probe_key "key = $ISSUE_KEY AND labels = \"AI-Workflow:auto\""; then
      MODE="Auto"; MODE_SOURCE="label"
    elif probe_key "key = $ISSUE_KEY AND labels = \"AI-Workflow:full-auto\""; then
      MODE="Full Auto"; MODE_SOURCE="label"
    fi
  fi
fi

printf 'MODE=%s\n' "$MODE"
printf 'MODE_SOURCE=%s\n' "$MODE_SOURCE"
exit 0
