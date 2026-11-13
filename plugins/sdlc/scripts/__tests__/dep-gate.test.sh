#!/usr/bin/env bash
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
src="$here/../dep-gate.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/scripts" "$work/bin"
cp "$src" "$work/scripts/dep-gate.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$work/scripts/jira-site-guard.sh"

cat > "$work/bin/acli" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  "jira workitem view S-1 --fields parent --json")
    case "${MOCK_PARENT:-epic}" in
      none) echo '{"fields":{"parent":null}}' ;;
      fail) exit 1 ;;
      junk) echo '[]' ;;
      *)    echo '{"fields":{"parent":{"key":"EP-1"}}}' ;;
    esac ;;
  "jira workitem search --jql parent = EP-1 --json") echo '[{"key":"S-1"},{"key":"B-1"}]' ;;
  "jira workitem link list --key B-1 --json") echo '{"issueLinks":[{"typeName":"Blocks","outwardIssueKey":"S-1"}]}' ;;
  # real acli 1.3.22: `--fields key` turns each hit into `null`, so the mock does too
  "jira workitem search --jql key = B-1 AND labels = \"UI-Components\" --fields key --json")
    if [ "${MOCK_UI:-0}" = 1 ]; then echo '[null]'; else echo '[]'; fi ;;
  "jira workitem search --jql key = B-1 AND labels = \"UI-Components\" --json")
    [ "${MOCK_LABEL_FAIL:-0}" = 1 ] && exit 1
    [ "${MOCK_LABEL_FAIL:-0}" = 2 ] && { echo '[]'; exit 1; }
    if [ "${MOCK_UI:-0}" = 1 ]; then echo '[{"key":"B-1","fields":{"summary":"s"}}]'; else echo '[]'; fi ;;
  "jira workitem search --jql key = B-1 AND labels = \"Design\" --json")
    [ "${MOCK_DESIGN_FAIL:-0}" = 1 ] && exit 1
    if [ "${MOCK_DESIGN:-0}" = 1 ]; then echo '[{"key":"B-1"}]'; else echo '[]'; fi ;;
  "jira workitem search --jql key = B-1 AND statusCategory = Done --json")
    [ "${MOCK_DONE_FAIL:-0}" = 1 ] && exit 1
    if [ "${MOCK_DONE:-0}" = 1 ]; then echo '[{"key":"B-1"}]'; else echo '[]'; fi ;;
  "jira workitem search --jql key = S-1 AND labels = \"Design\" --json")
    if [ "${MOCK_SELF_DESIGN:-0}" = 1 ]; then echo '[{"key":"S-1"}]'; else echo '[]'; fi ;;
  "jira workitem view S-1 --fields issuetype --json")
    [ "${MOCK_ITYPE:-Story}" = fail ] && exit 1
    echo "{\"fields\":{\"issuetype\":{\"name\":\"${MOCK_ITYPE:-Story}\"}}}" ;;
  *) echo '[]' ;;
esac
EOF

cat > "$work/bin/gh" <<'EOF'
#!/usr/bin/env bash
head="" state=""
while [ $# -gt 0 ]; do
  case "$1" in
    --head) head="$2"; shift ;;
    --state) state="$2"; shift ;;
  esac
  shift
done
pr="${MOCK_PR:-none}"
if [ "$head" = "${MOCK_HEAD:-feat}/B-1" ] && { [ "$pr" = merged ] || { [ "$pr" = open ] && [ "$state" = all ]; }; }; then
  echo '[{"number":1}]'
else
  echo '[]'
fi
EOF
chmod +x "$work/bin/acli" "$work/bin/gh" "$work/scripts/"*.sh

pass=0 fail=0
check() {
  local name="$1" want_rc="$2" want_line="$3"; shift 3
  local out rc
  out="$(env PATH="$work/bin:$PATH" "$@" bash "$work/scripts/dep-gate.sh" S-1 2>&1)"; rc=$?
  local mode=-qF
  case "$want_line" in "="*) mode=-qxF; want_line="${want_line#=}" ;; esac
  if [ "$rc" -eq "$want_rc" ] && printf '%s\n' "$out" | grep "$mode" -- "$want_line"; then
    pass=$((pass + 1)); echo "ok   $name"
  else
    fail=$((fail + 1)); echo "FAIL $name (rc=$rc, want $want_rc, line '$want_line')"; printf '%s\n' "$out" | sed 's/^/     /'
  fi
}

check "plain blocker, open PR passes"            0 "GATE=PASS"          MOCK_UI=0 MOCK_PR=open
check "plain blocker, no PR stops"               1 "B-1 PR: NO"         MOCK_UI=0 MOCK_PR=none
check "UI-Components blocker, open PR stops"     1 "B-1 PR: unmerged"   MOCK_UI=1 MOCK_PR=open
check "UI-Components blocker, open PR reason"    1 "not merged"         MOCK_UI=1 MOCK_PR=open
check "UI-Components blocker, no PR stops"       1 "B-1 PR: NO"         MOCK_UI=1 MOCK_PR=none
check "UI-Components blocker, merged PR passes"  0 "GATE=PASS"          MOCK_UI=1 MOCK_PR=merged
check "UI-Components blocker is named"           0 "=UI_BLOCKERS=B-1"   MOCK_UI=1 MOCK_PR=merged
check "plain blocker is not named"               0 "=UI_BLOCKERS="      MOCK_UI=0 MOCK_PR=open
check "UI-Components merged fix/ PR passes"      0 "GATE=PASS"          MOCK_UI=1 MOCK_PR=merged MOCK_HEAD=fix
check "UI-Components open fix/ PR stops"         1 "B-1 PR: unmerged"   MOCK_UI=1 MOCK_PR=open MOCK_HEAD=fix
check "label lookup failure stops"               1 "cannot read labels" MOCK_LABEL_FAIL=1 MOCK_PR=merged
check "label lookup error with output stops"     1 "cannot read labels" MOCK_LABEL_FAIL=2 MOCK_PR=merged

check "open Design story stops a UI story"        1 "B-1 PR: design"     MOCK_DESIGN=1 MOCK_PR=none
check "open Design story names the command"       1 "run /sdlc:design EP-1 --final first" MOCK_DESIGN=1 MOCK_PR=none
check "open Design story is listed"               1 "=DESIGN_BLOCKERS=B-1" MOCK_DESIGN=1 MOCK_PR=none
check "a PR never satisfies an open Design story" 1 "B-1 PR: design"     MOCK_DESIGN=1 MOCK_PR=merged
check "Done Design story passes with no PR"       0 "GATE=PASS"          MOCK_DESIGN=1 MOCK_DONE=1 MOCK_PR=none
check "Done Design story is not listed"           0 "=DESIGN_BLOCKERS="  MOCK_DESIGN=1 MOCK_DONE=1 MOCK_PR=none
check "Bug is not held by an open Design story"   0 "GATE=PASS"          MOCK_DESIGN=1 MOCK_ITYPE=Bug MOCK_PR=none
check "Bug's Design blocker reads n/a"            0 "B-1 PR: n/a"        MOCK_DESIGN=1 MOCK_ITYPE=Bug MOCK_PR=none
check "Bug still waits for a plain blocker"       1 "B-1 PR: NO"         MOCK_ITYPE=Bug MOCK_PR=none
check "unreadable issue type holds the story"     1 "B-1 PR: design"     MOCK_DESIGN=1 MOCK_ITYPE=fail MOCK_PR=none
check "Done plain blocker passes with no PR"      0 "B-1 PR: done"       MOCK_DONE=1 MOCK_PR=none
check "Done UI-Components blocker still needs a merge" 1 "B-1 PR: unmerged" MOCK_UI=1 MOCK_DONE=1 MOCK_PR=open
check "the Design story itself is refused"        1 "S-1 is the Design story of EP-1" MOCK_SELF_DESIGN=1
check "Design label lookup failure stops"         1 "cannot read labels" MOCK_DESIGN_FAIL=1 MOCK_PR=merged
check "story with no parent epic is not held"     0 "GATE=PASS"          MOCK_PARENT=none
check "Bug with no parent epic is not held"       0 "=BLOCKERS="         MOCK_PARENT=none MOCK_ITYPE=Bug
check "unreadable parent stops"                   1 "cannot resolve parent epic" MOCK_PARENT=fail
check "unparseable parent answer stops"           1 "cannot resolve parent epic" MOCK_PARENT=junk
check "status lookup failure stops"               1 "cannot read the status" MOCK_DONE_FAIL=1 MOCK_PR=merged

cat > "$work/bin/acli" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  "jira workitem view S-1 --fields parent --json") echo '{"fields":{"parent":{"key":"EP-1"}}}' ;;
  "jira workitem search --jql parent = EP-1 --json") echo '[{"key":"S-1"},{"key":"D-1"}]' ;;
  "jira workitem search --jql key = D-1 AND labels = \"Design\" --json") echo '[{"key":"D-1"}]' ;;
  "jira workitem link list --key D-1 --json") echo '{"issueLinks":[{"typeName":"Blocks","outwardIssueKey":"S-9"}]}' ;;
  *) echo '[]' ;;
esac
EOF
check "backend story the open Design story does not block proceeds" 0 "GATE=PASS"
check "backend story has no blockers"                               0 "=BLOCKERS="

echo "dep-gate: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
