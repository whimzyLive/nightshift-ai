#!/usr/bin/env bash
# Answer the two runtime questions the unit tests CANNOT answer, as cheaply as
# it is possible to answer them.
#
#   Q1  Does `claude -p "/some:command"` expand a slash command?
#       The SDLC adapter's entire prompt is `/sdlc:auto <KEY>`. If expansion
#       does not happen headlessly, that prompt is literal text and the cell
#       measures nothing.
#
#   Q2  Does a PreToolUse hook declared in .claude/settings.local.json fire in
#       a headless session?
#       bench_guard.py is verified exhaustively by piping payloads into it, but
#       that proves the LOGIC, not that Claude Code loads it from a project
#       file. If it silently does not load, ordinary pushes go unchecked.
#
# Cost control, because these are real sessions:
#   * Cheapest model, not the benchmark's model. Both questions are about the
#     harness, not about model quality, so paying Opus rates to answer them
#     would be waste.
#   * Every plugin disabled. A cold session's system prompt is the bulk of a
#     short session's cost, and plugin definitions are the bulk of that.
#   * Q1 uses a throwaway one-line command of our own rather than /sdlc:auto.
#     It asks whether EXPANSION happens -- the actual unknown -- without
#     loading the SDLC plugin or starting a lifecycle that would create a Jira
#     issue and a pull request.
#   * Two sessions total, a handful of tokens each.
#
# Safe: operates only inside a throwaway `bench/verify/*` worktree, removed at
# exit. Never pushes -- Q2 asks the session to attempt a push precisely so the
# guard can refuse it.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPTS="$REPO/plugins/bench/scripts"
MODEL="${VERIFY_MODEL:-claude-haiku-4-5-20251001}"
STAMP="$$"
BRANCH="bench/verify/$STAMP"
WT="$REPO/.bench-worktrees/verify-$STAMP"

cleanup() {
  git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1
  git -C "$REPO" branch -D "$BRANCH" >/dev/null 2>&1
  rmdir "$REPO/.bench-worktrees" >/dev/null 2>&1
  true
}
trap cleanup EXIT

echo "== bench harness runtime verification =="
echo "model: $MODEL (cheapest available -- these questions are about the"
echo "       harness, not about model quality)"
echo

# --- Refuse to spend anything if this would be API-billed -------------------
# Same rule the harness itself enforces. Presence only; never the value.
for var in ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN CLAUDE_CODE_SIMPLE; do
  if [ -n "${!var:-}" ]; then
    echo "ABORT: $var is set, so these probes would not be billed to your"
    echo "       subscription. Unset it and re-run. Nothing has been spent."
    exit 1
  fi
done

git -C "$REPO" worktree add -q -b "$BRANCH" "$WT" HEAD || {
  echo "ABORT: could not create the verification worktree."
  exit 1
}
mkdir -p "$WT/.claude/commands"

# Every plugin off, and the guard registered exactly as provision.py does it.
python3 - "$WT" "$SCRIPTS" <<'PY'
import subprocess, sys
from pathlib import Path
sys.path.insert(0, sys.argv[2])
import provision
from benchlib import environment

wt = Path(sys.argv[1])
# The real branch, so the guard's allow-list describes this worktree rather
# than a guess. An allow-list built from the wrong branch would deny the
# permitted case too, and Q2 would "pass" for the wrong reason.
branch = subprocess.run(
    ["git", "-C", str(wt), "rev-parse", "--abbrev-ref", "HEAD"],
    capture_output=True, text=True,
).stdout.strip()
record = environment.environment_record([], wt)
provision.write_guard_config(wt, "NA-VERIFY", branch, "verify")
provision.write_bench_settings(
    wt,
    enabled_plugins=record["enabled_plugins"],
    extra_allow=[],
    guard_script=Path(sys.argv[2]) / "bench_guard.py",
)
print("  wrote settings.local.json (all plugins disabled, guard registered)")
PY

cat > "$WT/.claude/commands/benchprobe.md" <<'EOF'
---
description: Harness verification probe
---

Reply with exactly this one word and nothing else: EXPANDED
EOF

# --- Q1: slash-command expansion -------------------------------------------
echo
echo "-- Q1: does a slash command expand in a headless session?"
Q1="$(cd "$WT" && claude --print --model "$MODEL" "/benchprobe" 2>&1)"
if printf '%s' "$Q1" | grep -q "EXPANDED"; then
  echo "   PASS: the command file was expanded and followed."
  # Single-quoted: backticks inside double quotes would be command-substituted.
  echo '         => the SDLC adapter'"'"'s "/sdlc:auto <KEY>" prompt will expand.'
else
  echo "   FAIL: the slash command did not expand."
  echo "         => the SDLC adapter cannot work as written; its prompt would"
  echo "            reach the model as literal text. Session said:"
  printf '%s\n' "$Q1" | head -5 | sed 's/^/            /'
fi

# --- Q2: does the PreToolUse guard fire? ------------------------------------
# Asked to push to develop, which the guard must refuse. A session that
# reports being blocked proves the hook loaded; one that reports a push
# succeeded, or a plain git error, proves it did not.
echo
echo "-- Q2: does the project-local PreToolUse guard fire headlessly?"
Q2="$(cd "$WT" && claude --print --model "$MODEL" --permission-mode acceptEdits \
  "Run exactly this command and report verbatim what happened, including any error or refusal text: git push origin develop" 2>&1)"
if printf '%s' "$Q2" | grep -qiE "benchmark cell may only push|outside that and was not pushed"; then
  echo "   PASS: the guard denied the push and its reason reached the session."
  echo "         => project-local hooks load in -p; the boundary is real."
elif printf '%s' "$Q2" | grep -qiE "permission|denied|blocked|not allowed"; then
  echo "   PARTIAL: something refused the push, but not with the guard's own"
  echo "            wording. That is most likely the blunt deny list, which"
  echo "            means the HOOK may not have loaded. Inspect:"
  printf '%s\n' "$Q2" | head -12 | sed 's/^/            /'
else
  echo "   FAIL or INCONCLUSIVE: no refusal detected. If the push was attempted"
  echo "            against the real remote, the guard did NOT load. Inspect:"
  printf '%s\n' "$Q2" | head -12 | sed 's/^/            /'
fi

echo
echo "Worktree and branch removed. Nothing was pushed."
echo "Not answered here (only a real cell can): whether SDLC's playbook"
echo "recovers from the guard's deny-and-retry, and the true per-cell cost."
