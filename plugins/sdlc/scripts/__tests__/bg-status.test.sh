#!/usr/bin/env bash
# bg-status.test.sh — verdicts of bg-status.sh and the claude command run-bg.sh builds, with
# claude/gh/acli stubbed on PATH and fixture transcripts. No network, no LLM.
#   bash plugins/sdlc/scripts/__tests__/bg-status.test.sh
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
scripts="$here/.."

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

repo="$work/repo"
home="$work/home"
mkdir -p "$repo/scripts" "$repo/.claude/project" "$work/bin" "$home/.claude/projects"
cp "$scripts/bg-status.sh" "$scripts/run-bg.sh" "$repo/scripts/"
printf '#!/usr/bin/env bash\nexit 0\n' > "$repo/scripts/jira-site-guard.sh"
git -C "$repo" init -q

NOW=1800000000
slug="$(printf '%s' "$repo" | sed 's/[^A-Za-z0-9]/-/g')"
tdir="$home/.claude/projects/$slug"
mkdir -p "$tdir"

# `claude agents --json --all` prints $MOCK_AGENTS; any other call is recorded to $CLAUDE_LOG.
cat > "$work/bin/claude" <<'STUB'
#!/usr/bin/env bash
if [ "${1:-}" = agents ]; then printf '%s\n' "${MOCK_AGENTS:-[]}"; exit 0; fi
{ for a in "$@"; do printf '[%s]' "$a"; done; echo; echo "KEY_SET=${ANTHROPIC_API_KEY:-unset} EXTRA=${BG_TEST_EXTRA:-}"; } > "$CLAUDE_LOG"
STUB
# gh prints $MOCK_PR (JSON array) for `pr list --head feat/<key>` only.
cat > "$work/bin/gh" <<'STUB'
#!/usr/bin/env bash
head=""
while [ $# -gt 0 ]; do [ "$1" = --head ] && head="$2"; shift; done
case "$head" in feat/*) printf '%s\n' "${MOCK_PR:-[]}" ;; *) echo '[]' ;; esac
STUB
cat > "$work/bin/acli" <<'STUB'
#!/usr/bin/env bash
printf '{"fields":{"status":{"name":"%s"}}}\n' "${MOCK_JIRA:-To Do}"
STUB
chmod +x "$work/bin/"*

# transcript <sid> <age-minutes> <last assistant text>
transcript() {
  local f="$tdir/$1.jsonl"
  printf '%s\n' '{"type":"user","message":{"content":"go"}}' \
    "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"text\",\"text\":\"$3\"}]}}" \
    '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash"}]}}' > "$f"
  python3 -I -c 'import os,sys; t=int(sys.argv[2])-int(sys.argv[3])*60; os.utime(sys.argv[1],(t,t))' "$f" "$NOW" "$2"
}

agents() { printf '[{"name":"%s","sessionId":"%s","cwd":"%s","kind":"background","status":"%s","startedAt":1}]' "$1" "$2" "$repo" "$3"; }
pr() { # number state isDraft body checks-json
  printf '[{"number":%s,"state":"%s","isDraft":%s,"body":"%s","statusCheckRollup":%s}]' "$1" "$2" "$3" "$4" "${5:-[]}"
}

pass=0 fail=0
ok()  { pass=$((pass + 1)); echo "ok   $1"; }
bad() { fail=$((fail + 1)); echo "FAIL $1"; shift; printf '     %s\n' "$@"; }

status() { (cd "$repo" && env PATH="$work/bin:$PATH" HOME="$home" BG_STATUS_NOW="$NOW" "$@" bash scripts/bg-status.sh S-1 2>&1); }
expect() { # name needle -- env...
  local name="$1" needle="$2" out; shift 3
  out="$(status "$@")"
  if printf '%s\n' "$out" | grep -qF -- "$needle"; then ok "$name"; else bad "$name (want '$needle')" "$out"; fi
}

SID=11111111-2222-3333-4444-555555555555
rm -f "$tdir"/*.jsonl

transcript $SID 2 "Implementing the story."
expect "RUNNING: fresh transcript, no PR" "S-1 verdict=RUNNING" -- MOCK_AGENTS="$(agents S-1 $SID working)"

transcript $SID 2 "Draft PR opened, still going."
expect "RUNNING: draft PR but transcript still fresh" "verdict=RUNNING" -- \
  MOCK_AGENTS="$(agents S-1 $SID working)" MOCK_PR="$(pr 7 OPEN true "body")"

transcript $SID 10 "Opened the PR."
expect "NEEDS_HUMAN: quiet run with draft PR while state=working" "verdict=NEEDS_HUMAN reason=draft-pr" -- \
  MOCK_AGENTS="$(agents S-1 $SID working)" MOCK_PR="$(pr 7 OPEN true "body")"

transcript $SID 1 "NEEDS YOU: pick option A or B."
expect "NEEDS_HUMAN: last message starts NEEDS YOU while state=working" "verdict=NEEDS_HUMAN reason=last-message" -- \
  MOCK_AGENTS="$(agents S-1 $SID working)"

transcript $SID 1 "Working."
expect "NEEDS_HUMAN: PR body heading" "verdict=NEEDS_HUMAN reason=pr-heading" -- \
  MOCK_AGENTS="$(agents S-1 $SID working)" MOCK_PR="$(pr 7 OPEN false '## Needs a human\n- decide X')"

transcript $SID 30 "Waiting on a long job."
expect "STALLED: no transcript write for 30 min" "verdict=STALLED reason=no-write-30m" -- \
  MOCK_AGENTS="$(agents S-1 $SID working)"

transcript $SID 1 "Working."
expect "STALLED: state blocked" "verdict=STALLED reason=state-blocked" -- \
  MOCK_AGENTS="$(agents S-1 $SID blocked)"

# question_transcript <project dir> <sid> <age-minutes> [answered]: last assistant block is an
# AskUserQuestion tool_use; with `answered`, a user tool_result follows it.
question_transcript() {
  local f="$1/$2.jsonl"
  mkdir -p "$1"
  printf '%s\n' '{"type":"user","message":{"content":"go"}}' \
    '{"type":"assistant","message":{"content":[{"type":"text","text":"Checking the design."}]}}' \
    '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"tu_1","name":"AskUserQuestion","input":{"questions":[{"question":"How should it relate to\nthe existing select?","header":"Reuse","options":[{"label":"New sibling"},{"label":"Generalise"}]},{"question":"Which variants?","header":"Variants","options":[]}]}}]}}' > "$f"
  [ "${4:-}" = answered ] && printf '%s\n' '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"tu_1","content":"New sibling"}]}}' >> "$f"
  printf '%s\n' '{"type":"cost-state","value":1}' '{"type":"last-prompt","value":"go"}' >> "$f"
  python3 -I -c 'import os,sys; t=int(sys.argv[2])-int(sys.argv[3])*60; os.utime(sys.argv[1],(t,t))' "$f" "$NOW" "$3"
}
# agents_in <cwd> <state|null> <status|null>: the two-field shape of `claude agents --json`.
agents_in() {
  local st="$2" su="$3"
  [ "$st" = null ] || st="\"$st\""
  [ "$su" = null ] || su="\"$su\""
  printf '[{"name":"S-1","sessionId":"%s","cwd":"%s","kind":"background","state":%s,"status":%s,"startedAt":1}]' "$SID" "$1" "$st" "$su"
}
encode() { printf '%s' "$1" | sed 's/[^A-Za-z0-9]/-/g'; }

rm -f "$tdir"/*.jsonl
question_transcript "$tdir" $SID 5
expect "NEEDS_HUMAN: blocked on AskUserQuestion" "verdict=NEEDS_HUMAN reason=question" -- \
  MOCK_AGENTS="$(agents_in "$repo" blocked waiting)"
expect "question: header and first question on one line, last field" \
  "needs_heading=no question=Reuse: How should it relate to the existing select? (+1 more)" -- \
  MOCK_AGENTS="$(agents_in "$repo" blocked waiting)"
expect "NEEDS_HUMAN: state blocked with a null status" "verdict=NEEDS_HUMAN reason=question" -- \
  MOCK_AGENTS="$(agents_in "$repo" blocked null)"
expect "question: text is cut at QUESTION_MAX" "question=Reuse: How..." -- \
  MOCK_AGENTS="$(agents_in "$repo" blocked waiting)" QUESTION_MAX=10
out="$(status MOCK_AGENTS="$(agents_in "$repo" blocked waiting)")"
if [ "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" = 1 ]; then ok "question: status stays one line"; else bad "question: status stays one line" "$out"; fi

expect "RUNNING: pending question but the session is not blocked" "verdict=RUNNING" -- \
  MOCK_AGENTS="$(agents_in "$repo" working busy)"
out="$(status MOCK_AGENTS="$(agents_in "$repo" working busy)")"
case "$out" in *question=*) bad "no question field unless reason=question" "$out" ;; *) ok "no question field unless reason=question" ;; esac

question_transcript "$tdir" $SID 5 answered
expect "STALLED: blocked after the question was answered" "verdict=STALLED reason=state-blocked" -- \
  MOCK_AGENTS="$(agents_in "$repo" blocked waiting)"
transcript $SID 5 "Working."
expect "STALLED: waiting with no pending question" "verdict=STALLED reason=state-waiting" -- \
  MOCK_AGENTS="$(agents_in "$repo" null waiting)"
expect "STALLED: state blocked with a null status, no question" "reason=state-blocked session=$SID state=blocked idle_min=5" -- \
  MOCK_AGENTS="$(agents_in "$repo" blocked null)"

# Transcript location: a story run's cwd is its worktree, so its project dir is the worktree's encoding.
rm -f "$tdir"/*.jsonl
wt="$repo/.claude/worktrees/sdlc-S-1"
wt_dir="$home/.claude/projects/$(encode "$wt")"
case "$wt_dir" in *--claude-worktrees-sdlc-S-1) ok "worktree cwd encodes / and . to -" ;; *) bad "worktree cwd encodes / and . to -" "$wt_dir" ;; esac
question_transcript "$home/.claude/projects/-aaa-stale-copy" $SID 40 answered
question_transcript "$wt_dir" $SID 7
expect "transcript: read from the session cwd's project dir, not the repo root's" \
  "verdict=NEEDS_HUMAN reason=question session=$SID state=waiting idle_min=7" -- \
  MOCK_AGENTS="$(agents_in "$wt" blocked waiting)"
rm -rf "$wt_dir" "$home/.claude/projects/-aaa-stale-copy"

question_transcript "$home/.claude/projects/-somewhere-else" $SID 9
expect "transcript: found by session id when the cwd's project dir has none" \
  "verdict=NEEDS_HUMAN reason=question session=$SID state=waiting idle_min=9" -- \
  MOCK_AGENTS="$(agents_in "$wt" blocked waiting)"
expect "transcript: found by session id when the entry has no cwd" "idle_min=9" -- \
  MOCK_AGENTS="[{\"name\":\"S-1\",\"sessionId\":\"$SID\",\"state\":\"blocked\",\"startedAt\":1}]"
rm -rf "$home/.claude/projects/-somewhere-else"
expect "transcript: none anywhere leaves idle_min empty and the run STALLED" \
  "verdict=STALLED reason=state-blocked session=$SID state=waiting idle_min=-" -- \
  MOCK_AGENTS="$(agents_in "$wt" blocked waiting)"

transcript $SID 10 "Done."
expect "DONE: PR merged" "verdict=DONE reason=merged" -- \
  MOCK_AGENTS="$(agents S-1 $SID idle)" MOCK_PR="$(pr 7 MERGED false body)"
expect "DONE: Jira Done, no session" "verdict=DONE reason=jira-done" -- MOCK_JIRA=Done

expect "NO_SESSION: nothing known" "verdict=NO_SESSION" -- MOCK_AGENTS='[]'

expect "open ready PR with no checks reports none, not pending" "checks=none" -- \
  MOCK_AGENTS="$(agents S-1 $SID working)" MOCK_PR="$(pr 7 OPEN false body)"
expect "open ready PR with no checks is ready-to-merge" "reason=ready-to-merge" -- \
  MOCK_AGENTS="$(agents S-1 $SID working)" MOCK_PR="$(pr 7 OPEN false body)"
expect "pending check keeps the run RUNNING" "verdict=RUNNING reason=checks-pending" -- \
  MOCK_AGENTS="$(agents S-1 $SID working)" \
  MOCK_PR="$(pr 7 OPEN false body '[{"status":"IN_PROGRESS","conclusion":""}]')"
expect "failing check needs a human" "reason=checks-failing" -- \
  MOCK_AGENTS="$(agents S-1 $SID working)" \
  MOCK_PR="$(pr 7 OPEN false body '[{"status":"COMPLETED","conclusion":"FAILURE"}]')"

# run-bg.sh
contains() {
  if grep -qF -- "$2" "$work/claude.log"; then ok "$1"; else bad "$1 (want '$2')" "$(cat "$work/claude.log" 2>/dev/null)"; fi
}
rc_is() { # name want-rc args...
  local name="$1" want="$2" rc; shift 2
  (cd "$repo" && env PATH="$work/bin:$PATH" bash scripts/run-bg.sh "$@" >/dev/null 2>&1); rc=$?
  if [ "$rc" = "$want" ]; then ok "$name"; else bad "$name (rc=$rc, want $want)"; fi
}

rc_is "run-bg: no key is a usage error" 2
rc_is "run-bg: bad key refused" 2 "x; rm"

(cd "$repo" && env PATH="$work/bin:$PATH" CLAUDE_LOG="$work/claude.log" ANTHROPIC_API_KEY=secret bash scripts/run-bg.sh S-1 "mind the cache")
contains "run-bg start: --bg with name" "[--bg][-n][S-1][--permission-mode][auto]"
contains "run-bg start: prompt runs /sdlc:auto" "[/sdlc:auto S-1"
contains "run-bg start: note in prompt" "mind the cache"
contains "run-bg start: rules carry the handoff convention" "Needs a human"
contains "run-bg start: rules carry NEEDS YOU" "NEEDS YOU:"
contains "run-bg start: rules forbid SendMessage resume" "never resume an agent with SendMessage"
contains "run-bg start: rules forbid AskUserQuestion" "Never call AskUserQuestion in a background run"
contains "run-bg start: rules send questions through the handoff" "do the human handoff instead"
contains "run-bg: ANTHROPIC_API_KEY unset" "KEY_SET=unset"

(cd "$repo" && env PATH="$work/bin:$PATH" CLAUDE_LOG="$work/claude.log" bash scripts/run-bg.sh S-1 "carry on" "$SID")
contains "run-bg resume: --resume with the full id" "[--bg][--resume][$SID]"
contains "run-bg resume: note is the prompt" "[carry on]"
contains "run-bg resume: rules forbid AskUserQuestion" "Never call AskUserQuestion in a background run"
if grep -qF -- "[-n]" "$work/claude.log"; then bad "run-bg resume: no -n"; else ok "run-bg resume: no -n"; fi

rm -f "$work/claude.log"
rc_is "run-bg: empty third arg refuses" 2 S-1 "carry on" ""
rc_is "run-bg: short resume id refuses" 2 S-1 "carry on" 39d88595
if [ -e "$work/claude.log" ]; then bad "run-bg: refusals launch nothing"; else ok "run-bg: refusals launch nothing"; fi
(cd "$repo" && env PATH="$work/bin:$PATH" CLAUDE_LOG="$work/claude.log" bash scripts/run-bg.sh S-1 "carry on" "" 2>"$work/err.txt")
if grep -q "resume session id was expected" "$work/err.txt"; then ok "run-bg: empty id error names the cause"; else bad "run-bg: empty id error names the cause"; fi
(cd "$repo" && env PATH="$work/bin:$PATH" CLAUDE_LOG="$work/claude.log" bash scripts/run-bg.sh S-1 "carry on" 39d88595 2>"$work/err.txt")
if grep -q "claude agents --json" "$work/err.txt"; then ok "run-bg: short id error says to expand it"; else bad "run-bg: short id error says to expand it"; fi
(cd "$repo" && env PATH="$work/bin:$PATH" CLAUDE_LOG="$work/claude.log" bash scripts/run-bg.sh S-1 "carry on" "$SID")
contains "run-bg: full id resumes" "[--bg][--resume][$SID]"
(cd "$repo" && env PATH="$work/bin:$PATH" CLAUDE_LOG="$work/claude.log" bash scripts/run-bg.sh S-1)
contains "run-bg: no third arg starts fresh" "[--bg][-n][S-1]"

cat > "$repo/.claude/project/bg-run.env" <<'ENV'
BG_RUN_PERMISSION_MODE=acceptEdits
BG_RUN_EXTRA_RULES="Repo rule: use the local database."
BG_TEST_EXTRA=from-env
ENV
(cd "$repo" && env PATH="$work/bin:$PATH" CLAUDE_LOG="$work/claude.log" bash scripts/run-bg.sh S-1)
contains "bg-run.env: permission mode" "[--permission-mode][acceptEdits]"
contains "bg-run.env: extra rules appended" "Repo rule: use the local database."
contains "bg-run.env: other variables exported" "EXTRA=from-env"

echo
echo "bg-status: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
