#!/usr/bin/env bash
# run-bg.sh — start (or resume) one background Claude Code session that runs /sdlc:auto for a story.
# Usage: run-bg.sh KEY [note] [resume-session-id]
#   KEY                 Jira story key. Becomes the session name (`claude attach KEY`).
#   note                Extra instruction. Appended to the prompt on a start; the whole prompt on a resume.
#   resume-session-id   Full session id of a stopped run to continue instead of starting a new one.
#
# Per-repo settings are read from the optional .claude/project/bg-run.env (sourced, shell syntax):
#   BG_RUN_PERMISSION_MODE   default auto
#   BG_RUN_COMMAND           default /sdlc:auto
#   BG_RUN_EXTRA_RULES       appended to the rules text below
#   any other variable is exported to the session (e.g. a gate's base ref)
# Rules and operating guide: refs/bg-runs.md. Subscription billing: ANTHROPIC_API_KEY is unset.
set -uo pipefail

key="${1:-}"
note="${2:-}"
resume="${3:-}"

if ! printf '%s' "$key" | grep -qE '^[A-Za-z][A-Za-z0-9]*-[0-9]+$'; then
  echo "usage: run-bg.sh KEY [note] [resume-session-id]  (KEY like ABC-123)" >&2
  exit 2
fi

root="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "run-bg.sh: not inside a git repository" >&2; exit 1; }
cd "$root" || exit 1

if [ -r .claude/project/bg-run.env ]; then
  set -a
  # shellcheck source=/dev/null
  . .claude/project/bg-run.env
  set +a
fi

unset ANTHROPIC_API_KEY

mode="${BG_RUN_PERMISSION_MODE:-auto}"
command_name="${BG_RUN_COMMAND:-/sdlc:auto}"

rules="Dispatch every agent in the foreground and wait for its result; never end a turn while an agent is running. Use a fresh agent for each fix round and each re-review; never resume an agent with SendMessage. Never grow an allowance list, skip a check or silence a gate to get a pass; report the failure instead. Work only in your own worktree and never touch the uncommitted files of the primary checkout. HUMAN HANDOFF: when you stop because a person must decide, open the PR as a DRAFT, put a section headed 'Needs a human' in the PR body that lists each decision, comment the same list on the Jira story, and start your last message with 'NEEDS YOU:' followed by the decisions."
[ -n "${BG_RUN_EXTRA_RULES:-}" ] && rules="$rules $BG_RUN_EXTRA_RULES"

if [ -n "$resume" ]; then
  exec claude --bg --resume "$resume" --permission-mode "$mode" --append-system-prompt "$rules" "${note:-continue}"
fi

prompt="$command_name $key"
[ -n "$note" ] && prompt="$prompt
Note from the launcher: $note"
exec claude --bg -n "$key" --permission-mode "$mode" --append-system-prompt "$rules" "$prompt"
