#!/usr/bin/env bash
# Stream what a measured cell is doing, live.
#
# `execute.py` runs `claude --print --output-format json` with output captured,
# and that format emits one JSON blob at the very end -- so there is nothing to
# stream from the harness side. A full SDLC lifecycle is 20+ minutes of total
# silence, which is indistinguishable from a hang and has already been read as
# a failed run when the run was fine.
#
# Claude Code writes its session transcript incrementally, so that file is the
# live signal. This tails it and prints one compact line per event.
#
# Read-only. Touches nothing the harness owns, so it cannot affect the
# measurement -- which is the whole reason it is a separate script rather than
# a change to execute.py's subprocess handling.
#
# Usage:
#   bash watch-cell.sh                       # newest bench cell, waits for it
#   bash watch-cell.sh NA-82-sdlc@0.45.4-r2  # a specific worktree
set -uo pipefail

PROJECTS="$HOME/.claude/projects"
FILTER="${1:-}"

# Claude Code derives a project directory from the worktree path by replacing
# every non-alphanumeric run with a dash, so `.bench-worktrees/NA-82-sdlc@0.45.4-r2`
# becomes `--bench-worktrees-NA-82-sdlc-0-45-4-r2`. Matching on the literal
# worktree name therefore fails; normalise the filter the same way.
if [ -n "$FILTER" ]; then
  NORM="$(printf '%s' "$FILTER" | sed 's/[^A-Za-z0-9]\{1,\}/-/g')"
  PATTERN="*bench-worktrees*${NORM}"
else
  PATTERN="*bench-worktrees*"
fi

echo "watching for a bench cell transcript ..."
TRANSCRIPT=""
for _ in $(seq 1 120); do
  # Newest .jsonl under any matching project dir. Newest rather than "the one
  # for this cell" because the session id is not known until the run ends --
  # that id only appears in the result payload.
  # shellcheck disable=SC2086
  TRANSCRIPT="$(ls -t $PROJECTS/$PATTERN/*.jsonl 2>/dev/null | head -1)"
  [ -n "$TRANSCRIPT" ] && break
  sleep 2
done

if [ -z "$TRANSCRIPT" ]; then
  echo "no bench transcript found under $PROJECTS/$PATTERN"
  echo "Is a cell actually running? Check: ps -ef | grep execute.py"
  exit 1
fi

echo "-> $TRANSCRIPT"
echo "   (Ctrl-C stops watching. It does NOT stop the run -- the cell keeps"
echo "    going, and killing this script cannot affect the measurement.)"
echo

# -n +1 so an already-started session replays from the beginning rather than
# showing only what happens after you attach.
tail -n +1 -f "$TRANSCRIPT" | python3 -u -c '
import json, sys

# Tool inputs worth showing, in the order they best identify what a call DID.
FIELDS = ("subagent_type", "skill", "command", "file_path", "pattern", "url", "description")
last_agent = None

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        e = json.loads(line)
    except ValueError:
        continue

    # A sidechain entry belongs to a dispatched subagent, not the main session.
    # Marked so a burst of tool calls is attributable to the agent doing them.
    side = "  |" if e.get("isSidechain") else ""

    msg = e.get("message") or {}
    content = msg.get("content")
    if not isinstance(content, list):
        continue

    for part in content:
        if not isinstance(part, dict):
            continue
        kind = part.get("type")

        if kind == "text":
            text = (part.get("text") or "").strip()
            if text:
                # First line only: narration is often several paragraphs and
                # the point here is a progress trace, not a transcript.
                head = text.splitlines()[0]
                print(f"{side} » {head[:150]}")

        elif kind == "tool_use":
            name = part.get("name") or "?"
            data = part.get("input") if isinstance(part.get("input"), dict) else {}
            detail = ""
            for f in FIELDS:
                v = data.get(f)
                if isinstance(v, str) and v.strip():
                    detail = v.strip().splitlines()[0]
                    break
            # An agent dispatch is the phase boundary the report attributes
            # cost to, so it gets called out rather than listed as one more
            # tool call.
            agent = data.get("subagent_type")
            if agent:
                print(f"{side} ┌─ DISPATCH {agent}")
            else:
                print(f"{side}   [{name}] {detail[:130]}")

        elif kind == "tool_result":
            ok = part.get("is_error")
            if ok:
                body = part.get("content")
                if isinstance(body, list):
                    body = " ".join(
                        p.get("text", "") for p in body if isinstance(p, dict)
                    )
                # Errors are the thing worth seeing immediately -- notably a
                # guard denial, which arrives as a tool error.
                print(f"{side}   !! ERROR {str(body)[:160]}")
'
