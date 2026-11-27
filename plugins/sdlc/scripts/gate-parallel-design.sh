#!/usr/bin/env bash
set -uo pipefail
# gate-parallel-design.sh — whether the QA gate runs the design check alongside the test command
# (rules: refs/qa-gate-runner.md step 4a).
#
# Reads the optional `Gate parallel design check` row of the `## Tooling` section of
# project-context.md and prints GATE_PARALLEL_DESIGN=on|off. Row absent, empty or `on` -> on;
# `off` -> off. Any other value exits 1 with a message on stderr and prints nothing: the runner then
# keeps the serial order.

die() { echo "gate-parallel-design.sh: $*" >&2; exit 1; }

# project-context.md: this checkout first, then the primary checkout (a linked worktree of a repo
# whose context file is untracked does not have its own copy), then the session's project dir.
find_ctx() {
  local top common cand
  top="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  common="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  [ -n "$common" ] || common="$(cd "$(git rev-parse --git-common-dir 2>/dev/null)" 2>/dev/null && pwd -P || true)"
  for cand in "$top" "${common%/.git}" "${CLAUDE_PROJECT_DIR:-}" "$PWD"; do
    [ -n "$cand" ] && [ -r "$cand/.claude/project/project-context.md" ] \
      && { printf '%s' "$cand/.claude/project/project-context.md"; return 0; }
  done
  return 1
}

VAL=""
if ctx="$(find_ctx)"; then
  VAL="$(awk -F'|' '
    /^##[ \t]/ { insec = ($0 ~ /^##[ \t]+Tooling[ \t]*$/); next }
    insec && tolower($2) ~ /^[ \t]*gate parallel design check[ \t]*$/ {
      v = $3; gsub(/^[ \t`]+|[ \t`]+$/, "", v); print v; exit
    }' "$ctx")"
fi

case "$(printf '%s' "$VAL" | tr '[:upper:]' '[:lower:]')" in
  "" | on) echo "GATE_PARALLEL_DESIGN=on" ;;
  off) echo "GATE_PARALLEL_DESIGN=off" ;;
  *) die "Gate parallel design check '$VAL' in project-context.md is not on or off (leave the row out for on)" ;;
esac
