#!/usr/bin/env bash
# triage.test.sh — triage.sh routing (threshold from project-context, points probe, work kind)
# against a mocked acli, in a temp git repo.
#   bash plugins/sdlc/scripts/__tests__/triage.test.sh
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
src="$here/../triage.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/scripts" "$work/bin" "$work/repo"
cp "$src" "$work/scripts/triage.sh"
cat > "$work/scripts/jira-site-guard.sh" <<'STUB'
#!/usr/bin/env bash
[ "${MOCK_GUARD_FAIL:-0}" = 1 ] && exit 1
exit 0
STUB

# MOCK_ITYPE: issue-type name. MOCK_FIELD: the populated points field name (empty = none).
# MOCK_POINTS: its value. MOCK_FAIL=1: every acli call fails. Hits are `[null]`, the shape real
# acli 1.3.22 can return, so the suite proves hit counting does not depend on a key.
cat > "$work/bin/acli" <<'STUB'
#!/usr/bin/env bash
echo "$*" >> "${MOCK_LOG:-/dev/null}"
[ "${MOCK_FAIL:-0}" = 1 ] && { echo "acli: auth failed" >&2; exit 1; }
field="${MOCK_FIELD:-}"
case "$*" in
  *"workitem view"*) printf '{"fields":{"issuetype":{"name":"%s"}}}\n' "${MOCK_ITYPE:-Story}"; exit 0 ;;
  *"\"$field\" is not EMPTY"*) [ -n "$field" ] && { echo '[null]'; exit 0; } ;;
  *"\"$field\" = ${MOCK_POINTS:-none} --json"*) [ -n "$field" ] && { echo '[null]'; exit 0; } ;;
esac
echo '[]'
STUB
chmod +x "$work/bin/acli" "$work/scripts/"*.sh

write_ctx() { # <dir> <triage-section-body|NONE>
  mkdir -p "$1/.claude/project"
  {
    printf '# Project Context\n\n| Token | Value |\n| --- | --- |\n| Jira site | example.atlassian.net |\n\n## Memory\n\n| Token | Value |\n| --- | --- |\n| Lightweight threshold (story points, inclusive) | `99` |\n\n'
    [ "$2" = NONE ] || printf '## Triage\n\n| Token | Value |\n| --- | --- |\n| Lightweight threshold (story points, inclusive) | %s |\n\n## CI\n\n| Token | Value |\n| --- | --- |\n| Max attempts | `5` |\n' "$2"
  } > "$1/.claude/project/project-context.md"
}

repo="$work/repo"
git -C "$repo" init -q
git -C "$repo" config user.email t@example.com
git -C "$repo" config user.name t
echo x > "$repo/f"
git -C "$repo" add f
git -C "$repo" commit -qm init

pass=0 fail=0
# check <name> <want_rc> <want one-line output> <env...>  (run in $repo; args via TRIAGE_ARGS)
check() {
  local name="$1" want_rc="$2" want="$3"; shift 3
  local out rc
  out="$(cd "${RUN_DIR:-$repo}" && env PATH="$work/bin:$PATH" TRIAGE_RETRY_SLEEP=0 "$@" bash "$work/scripts/triage.sh" ${TRIAGE_ARGS:-S-1} 2>/dev/null)"; rc=$?
  out="$(printf '%s' "$out" | tr '\n' ' ')"
  out="${out% }"
  if [ "$rc" -eq "$want_rc" ] && [ "$out" = "$want" ]; then
    pass=$((pass + 1)); echo "ok   $name"
  else
    fail=$((fail + 1)); echo "FAIL $name (rc=$rc, want $want_rc, out '$out', want '$want')"
  fi
}

THR8='`8`'
write_ctx "$repo" "$THR8"
check "threshold 8, 5 points -> lightweight (consumer bug)" 0 \
  "WORK_KIND=feature TRIAGE=lightweight STORY_POINTS=5 THRESHOLD=8" MOCK_FIELD="Story Points" MOCK_POINTS=5
check "threshold 8, 13 points -> full" 0 \
  "WORK_KIND=feature TRIAGE=full STORY_POINTS=13 THRESHOLD=8" MOCK_FIELD="Story Points" MOCK_POINTS=13
check "exactly at threshold is lightweight" 0 \
  "WORK_KIND=feature TRIAGE=lightweight STORY_POINTS=8 THRESHOLD=8" MOCK_FIELD="Story point estimate" MOCK_POINTS=8
check "non-standard value found by the widened candidates" 0 \
  "WORK_KIND=feature TRIAGE=lightweight STORY_POINTS=0.5 THRESHOLD=8" MOCK_FIELD="Story point estimate" MOCK_POINTS=0.5
check "Bug with 13 points is lightweight/defect" 0 \
  "WORK_KIND=defect TRIAGE=lightweight STORY_POINTS=13 THRESHOLD=8" MOCK_ITYPE=Bug MOCK_FIELD="Story Points" MOCK_POINTS=13
check "Bug with missing points is lightweight/defect, no warning" 0 \
  "WORK_KIND=defect TRIAGE=lightweight STORY_POINTS=missing THRESHOLD=8" MOCK_ITYPE=Bug
check "missing points on a story -> full plus WARNING" 0 \
  "WARNING: Story points not set on S-1 — defaulting to the full (approved-spec) path. Set points in Jira before running /impl for the lightweight path. WORK_KIND=feature TRIAGE=full STORY_POINTS=missing THRESHOLD=8"

write_ctx "$repo" NONE
check "no Triage section, 5 points -> full at default 3 (99 in another section ignored)" 0 \
  "WORK_KIND=feature TRIAGE=full STORY_POINTS=5 THRESHOLD=3" MOCK_FIELD="Story Points" MOCK_POINTS=5
check "no Triage section, 3 points -> lightweight" 0 \
  "WORK_KIND=feature TRIAGE=lightweight STORY_POINTS=3 THRESHOLD=3" MOCK_FIELD="Story Points" MOCK_POINTS=3

write_ctx "$repo" '`lots`'
check "malformed threshold -> default 3 plus WARNING" 0 \
  "WARNING: Lightweight threshold in project-context.md is not an integer ('lots') — using the built-in default 3. WORK_KIND=feature TRIAGE=full STORY_POINTS=5 THRESHOLD=3" MOCK_FIELD="Story Points" MOCK_POINTS=5

write_ctx "$repo" "$THR8"
check "points set but outside the candidates -> non-zero, never reported missing" 1 "" MOCK_FIELD="Story Points" MOCK_POINTS=7777
check "acli failure -> non-zero, no routing block" 1 "" MOCK_FAIL=1
check "site guard failure -> non-zero, no routing block" 1 "" MOCK_GUARD_FAIL=1

log="$work/acli.log"; : > "$log"
TRIAGE_ARGS="S-1 Story" check "issue type argument -> routes without an issuetype fetch" 0 \
  "WORK_KIND=feature TRIAGE=lightweight STORY_POINTS=5 THRESHOLD=8" MOCK_FIELD="Story Points" MOCK_POINTS=5 MOCK_LOG="$log"
if grep -q "workitem view" "$log"; then fail=$((fail + 1)); echo "FAIL issue type argument still fetched issuetype"
else pass=$((pass + 1)); echo "ok   no issuetype fetch when the type is passed"; fi
TRIAGE_ARGS="S-1 BUG" check "issue type argument is case-insensitive" 0 \
  "WORK_KIND=defect TRIAGE=lightweight STORY_POINTS=missing THRESHOLD=8"

: > "$log"
check "without the argument the type is fetched once" 0 \
  "WORK_KIND=feature TRIAGE=lightweight STORY_POINTS=5 THRESHOLD=8" MOCK_FIELD="Story Points" MOCK_POINTS=5 MOCK_LOG="$log"
n="$(grep -c "workitem view" "$log")"
if [ "$n" -eq 1 ]; then pass=$((pass + 1)); echo "ok   one issuetype fetch"; else fail=$((fail + 1)); echo "FAIL issuetype fetches: $n"; fi

# Linked worktree of a repo whose project-context.md is untracked: the file exists only in the
# primary checkout and must still resolve.
git -C "$repo" worktree add -q "$work/wt" -b wt-branch
if [ -e "$work/wt/.claude/project/project-context.md" ]; then
  fail=$((fail + 1)); echo "FAIL worktree fixture has its own context file"
else
  RUN_DIR="$work/wt" check "linked worktree resolves the primary checkout's context" 0 \
    "WORK_KIND=feature TRIAGE=lightweight STORY_POINTS=5 THRESHOLD=8" MOCK_FIELD="Story Points" MOCK_POINTS=5
fi

echo "triage: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
