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
  "jira workitem view S-1 --fields parent --json") echo '{"fields":{"parent":{"key":"EP-1"}}}' ;;
  "jira workitem search --jql parent = EP-1 --json") echo '[{"key":"S-1"},{"key":"B-1"}]' ;;
  "jira workitem link list --key B-1 --json") echo '{"issueLinks":[{"typeName":"Blocks","outwardIssueKey":"S-1"}]}' ;;
  "jira workitem search --jql key = B-1 AND labels = \"UI-Components\" --fields key --json")
    [ "${MOCK_LABEL_FAIL:-0}" = 1 ] && exit 1
    [ "${MOCK_LABEL_FAIL:-0}" = 2 ] && { echo '[]'; exit 1; }
    if [ "${MOCK_UI:-0}" = 1 ]; then echo '[{"key":"B-1"}]'; else echo '[]'; fi ;;
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

echo "dep-gate: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
