#!/usr/bin/env bash
# design-story.test.sh — pins scripts/design-story.sh: one Design story per Epic (created once,
# reused after), the Blocks links in acli's --out <blocked> --in <blocker> direction, and the
# fail-closed exits. acli is a small stateful mock: created stories and links live in files.
#   bash plugins/sdlc/scripts/__tests__/design-story.test.sh
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
mkdir -p "$work/scripts" "$work/bin"
cp "$here/../design-story.sh" "$here/../dep-gate.sh" "$work/scripts/"
printf '#!/usr/bin/env bash\n[ "${MOCK_GUARD_FAIL:-0}" = 1 ] && { echo wrong-site >&2; exit 1; }\nexit 0\n' >"$work/scripts/jira-site-guard.sh"

cat >"$work/bin/acli" <<'EOF2'
#!/usr/bin/env bash
# State: $MOCK_STATE/design (keys of Design stories, one per line), $MOCK_STATE/links ("<blocker> <blocked>" per line)
echo "$*" >>"$MOCK_STATE/log"
touch "$MOCK_STATE/design" "$MOCK_STATE/links"
arr() { awk 'BEGIN{printf "["} NF{printf "%s{\"key\":\"%s\"}", (n++?",":""), $1} END{print "]"}'; }
case "$*" in
  'jira workitem search --jql parent = EP-1 AND labels = "Design" ORDER BY created ASC --json')
    [ "${MOCK_SEARCH_FAIL:-0}" = 1 ] && exit 1
    arr <"$MOCK_STATE/design" ;;
  'jira workitem search --jql parent = EP-1 AND labels = "Library" ORDER BY created ASC --json')
    printf '%s\n' ${MOCK_LIBS-L-1 L-2} | arr ;;
  'jira workitem search --jql parent = EP-1 AND labels = "Widgets" ORDER BY created ASC --json')
    printf 'W-1\n' | arr ;;
  'jira workitem search --jql key = '*' AND statusCategory = Done --json')
    if [ "${MOCK_DONE:-0}" = 1 ]; then head -1 "$MOCK_STATE/design" | arr; else echo '[]'; fi ;;
  'jira workitem search --jql parent = EP-1 AND key = '*' --json')
    if [ "${MOCK_ORPHAN:-0}" = 1 ]; then echo '[]'; else head -1 "$MOCK_STATE/design" | arr; fi ;;
  'jira workitem create '*)
    [ "${MOCK_CREATE_FAIL:-0}" = 1 ] && { echo 'denied by policy'; exit 1; }
    n=$(( $(wc -l <"$MOCK_STATE/design") + 1 ))
    echo "D-$n" >>"$MOCK_STATE/design"
    echo "{\"key\":\"D-$n\"}" ;;
  'jira workitem search --jql key = '*' AND labels = "Design" --json')
    k="${5#key = }"; grep -x "${k%% *}" "$MOCK_STATE/design" | arr ;;
  'jira workitem search --jql parent = EP-1 --json')
    { cat "$MOCK_STATE/design"; tr ' ' '\n' <"$MOCK_STATE/links"; } | sort -u | arr ;;
  'jira workitem view '*' --fields parent --json')
    echo '{"fields":{"parent":{"key":"EP-1"}}}' ;;
  'jira workitem view '*' --fields issuetype --json')
    echo '{"fields":{"issuetype":{"name":"Story"}}}' ;;
  'jira workitem link list --key '*' --json')
    awk -v k="$6" 'BEGIN{printf "{\"issueLinks\":["}
      $1==k{printf "%s{\"typeName\":\"Blocks\",\"outwardIssueKey\":\"%s\"}", (n++?",":""), $2}
      END{print "]}"}' "$MOCK_STATE/links" ;;
  'jira workitem view '*' --fields issuelinks --json')
    key="$4"
    [ "${MOCK_VIEW_FAIL:-0}" = 1 ] && exit 1
    awk -v k="$key" 'BEGIN{printf "{\"fields\":{\"issuelinks\":["}
      $2==k{printf "%s{\"type\":{\"name\":\"Blocks\"},\"inwardIssue\":{\"key\":\"%s\"}}", (n++?",":""), $1}
      $1==k{printf "%s{\"type\":{\"name\":\"Blocks\"},\"outwardIssue\":{\"key\":\"%s\"}}", (n++?",":""), $2}
      END{print "]}}"}' "$MOCK_STATE/links" ;;
  'jira workitem link create --out '*' --in '*' --type Blocks --yes')
    [ "${MOCK_LINK_FAIL:-0}" = 1 ] && exit 1
    [ "${MOCK_LINK_LOST:-0}" = 1 ] || echo "$8 $6" >>"$MOCK_STATE/links"
    # the real message names the pair backwards
    echo "Link created: $6 blocks $8" ;;
  *) echo '[]' ;;
esac
EOF2
printf '#!/usr/bin/env bash\necho "[]"\n' >"$work/bin/gh"
chmod +x "$work/bin/acli" "$work/bin/gh" "$work/scripts/"*.sh
echo "ACs" >"$work/desc.txt"

failures=0
check() { if [ "$2" = "$3" ]; then echo "ok   - $1"; else echo "FAIL - $1: expected '$2', got '$3'"; failures=$((failures + 1)); fi; }
state() { rm -rf "$work/state"; mkdir -p "$work/state"; }
run() {
  local envs=()
  while [ "$#" -gt 0 ]; do
    case "$1" in MOCK_*=*) envs+=("$1"); shift ;; *) break ;; esac
  done
  env PATH="$work/bin:$PATH" MOCK_STATE="$work/state" ${envs[@]+"${envs[@]}"} bash "$work/scripts/design-story.sh" EP-1 "$@" 2>&1
  echo "rc=$?"
}
gate() {
  local envs=()
  while [ "$#" -gt 1 ]; do envs+=("$1"); shift; done
  env PATH="$work/bin:$PATH" MOCK_STATE="$work/state" ${envs[@]+"${envs[@]}"} bash "$work/scripts/dep-gate.sh" "$1" 2>&1
}
line() { printf '%s\n' "$1" | sed -n "s/^$2=//p"; }
count() { grep -c "$@" "$work/state/log" || true; }

state
out="$(run find)"
check "find: none yet"                   "" "$(line "$out" DESIGN_STORY)"
check "find: none is not done"           "no" "$(line "$out" DESIGN_DONE)"
check "find writes nothing"              0 "$(count 'workitem create\|link create')"

out="$(run ensure --description-file "$work/desc.txt" --screens "S-1 S-2" --context "$work/none.md")"
check "ensure: creates the story"        "D-1" "$(line "$out" DESIGN_STORY)"
check "ensure: says it created it"       "yes" "$(line "$out" CREATED)"
check "ensure: blocked by every library story" "L-1 L-2" "$(line "$out" BLOCKED_BY)"
check "ensure: blocks every screen story" "S-1 S-2" "$(line "$out" BLOCKS)"
check "ensure: ok"                       "rc=0" "$(printf '%s\n' "$out" | tail -1)"
check "label is Design, never AI-Ready"  1 "$(count 'workitem create .*--label Design --json')"
check "AI-Ready is not set"              0 "$(count 'AI-Ready')"
check "summary names the Epic"           1 "$(count -e '--summary High-fidelity designs for EP-1 (final boards from the bundle)')"
check "created under the Epic"           1 "$(count -e '--project EP --type Story --parent EP-1')"
check "library link: --out design --in library" 1 "$(count 'link create --out D-1 --in L-1 --type Blocks --yes')"
check "screen link: --out screen --in design"   1 "$(count 'link create --out S-1 --in D-1 --type Blocks --yes')"

out="$(run ensure --description-file "$work/desc.txt" --screens "S-1 S-2")"
check "second run reuses the story"      "D-1" "$(line "$out" DESIGN_STORY)"
check "second run creates nothing"       "no" "$(line "$out" CREATED)"
check "still exactly one create call"    1 "$(count 'workitem create')"
check "still exactly four links"         4 "$(count 'link create')"

out="$(run ensure --screens "S-1 S-2 S-3")"
check "a new screen story is linked on a re-run" "S-1 S-2 S-3" "$(line "$out" BLOCKS)"
check "only the missing link is added"   5 "$(count 'link create')"
check "reuse needs no description file"  "rc=0" "$(printf '%s\n' "$out" | tail -1)"

out="$(run MOCK_DONE=1 find)"
check "find: Done story"                 "yes" "$(line "$out" DESIGN_DONE)"

echo "D-9" >>"$work/state/design"
out="$(run ensure --screens "S-1")"
check "a second Design story is reported, the first is used" "D-1|D-9" "$(line "$out" DESIGN_STORY)|$(line "$out" EXTRA)"
check "and no third is created"          1 "$(count 'workitem create')"

state
out="$(run ensure --description-file "$work/desc.txt" --screens "S-1" --library-label Widgets)"
check "--library-label wins"             "W-1" "$(line "$out" BLOCKED_BY)"
state; printf '| Library label | `Widgets` |\n' >"$work/ctx.md"
out="$(run ensure --description-file "$work/desc.txt" --context "$work/ctx.md")"
check "library label from the token"     "W-1" "$(line "$out" BLOCKED_BY)"

state
out="$(run MOCK_LIBS= ensure --description-file "$work/desc.txt" --screens "S-1")"
check "no library stories: still blocks the screens" "|S-1|rc=0" "$(line "$out" BLOCKED_BY)|$(line "$out" BLOCKS)|$(printf '%s\n' "$out" | tail -1)"

state
out="$(run ensure --screens "S-1")"
check "no story and no description stops" "rc=1" "$(printf '%s\n' "$out" | tail -1)"
check "and creates nothing"              0 "$(count 'workitem create')"

state
out="$(run MOCK_CREATE_FAIL=1 ensure --description-file "$work/desc.txt" --screens "S-1")"
check "refused create stops"             "RESULT=stop rc=1" "$(printf '%s\n' "$out" | tail -2 | paste -sd' ' -)"
check "refused create links nothing"     0 "$(count 'link create')"

state
out="$(run MOCK_ORPHAN=1 ensure --description-file "$work/desc.txt" --screens "S-1")"
check "story not under the Epic stops"   1 "$(printf '%s\n' "$out" | grep -c 'is not a child of EP-1')"

state
out="$(run MOCK_LINK_LOST=1 ensure --description-file "$work/desc.txt" --screens "S-1")"
check "a link that does not read back stops" 1 "$(printf '%s\n' "$out" | grep -c 'REASON=links not read back on D-1 for: L-1 L-2 S-1')"

state
out="$(run MOCK_LINK_FAIL=1 ensure --description-file "$work/desc.txt" --screens "S-1")"
check "failed link stops"                "rc=1" "$(printf '%s\n' "$out" | tail -1)"

state
out="$(run ensure --description-file "$work/desc.txt" --screens "L-1")"
check "a library story is never blocked by it" 1 "$(printf '%s\n' "$out" | grep -c 'L-1 is a library story')"

state
check "bad screen key stops before any write" "rc=1|0" "$(run ensure --description-file "$work/desc.txt" --screens 'S-1;x' | tail -1)|$(count 'workitem create')"
check "search failure fails closed"      "rc=1" "$(run MOCK_SEARCH_FAIL=1 find | tail -1)"
check "site guard fails closed"          "rc=1" "$(run MOCK_GUARD_FAIL=1 find | tail -1)"
check "unknown action is a usage error"  "rc=2" "$(run nope | tail -1)"

plan="$work/component-plan.md"
cat >"$plan" <<'EOF3'
# Component plan — Projects

Epic: EP-1
Drafts: canvas

| Surface | Pattern | Template | Component | Action | Explore | Story |
| --- | --- | --- | --- | --- | --- | --- |
| Project header | Page title | Detail page | PageTitle | reuse | no | — |
| Budget bar | Budget | — | BudgetBar | extend | no | L-1 |

Screens: project-detail
EOF3
empty_plan="$work/empty-plan.md"
cat >"$empty_plan" <<'EOF3'
# Component plan — Nothing to show

Epic: EP-1

| Surface | Pattern | Template | Component | Action | Explore | Story |
| --- | --- | --- | --- | --- | --- | --- |

| Other | Table |
| --- | --- |
| not a surface | row |
EOF3

state
out="$(run ensure --plan "$plan" --description-file "$work/desc.txt")"
check "plan time: creates the story with no screen story and no final board" "D-1|yes" "$(line "$out" DESIGN_STORY)|$(line "$out" CREATED)"
check "plan time: blocked by every library story" "L-1 L-2" "$(line "$out" BLOCKED_BY)"
check "plan time: blocks nothing yet"    "|rc=0" "$(line "$out" BLOCKS)|$(printf '%s\n' "$out" | tail -1)"
check "plan time: only the library links are made" "2|0" "$(count 'link create --out D-1 --in L-')|$(count 'link create --out [^D]')"

out="$(run ensure --plan "$plan" --description-file "$work/desc.txt")"
check "second plan run reuses the story" "D-1|no" "$(line "$out" DESIGN_STORY)|$(line "$out" CREATED)"
check "second plan run creates nothing and links nothing" "1|2" "$(count 'workitem create')|$(count 'link create')"

out="$(run MOCK_LIBS="L-1 L-2 L-3" ensure --plan "$plan" --description-file "$work/desc.txt")"
check "a library story raised by a later plan run is linked" "L-1 L-2 L-3" "$(line "$out" BLOCKED_BY)"

check "open plan-created story holds nothing before /stories" 0 "$(grep -c ' S-' "$work/state/links" || true)"
out="$(run MOCK_LIBS="L-1 L-2 L-3" ensure --description-file "$work/desc.txt" --screens "S-1 S-2")"
check "/stories after the plan reuses the plan-created story" "D-1|no" "$(line "$out" DESIGN_STORY)|$(line "$out" CREATED)"
check "/stories links every screen story to it" "S-1 S-2" "$(line "$out" BLOCKS)"
check "/stories creates no second Design story" "1|1" "$(count 'workitem create')|$(wc -l <"$work/state/design" | tr -d ' ')"
out="$(gate S-1)"
check "an open plan-created story holds its screen stories" "D-1|GATE=STOP" "$(line "$out" DESIGN_BLOCKERS)|$(printf '%s\n' "$out" | tail -1)"

state
out="$(run MOCK_LIBS= ensure --plan "$plan" --description-file "$work/desc.txt")"
check "plan with no library stories: still created, blocked by nothing" "D-1|yes||rc=0" "$(line "$out" DESIGN_STORY)|$(line "$out" CREATED)|$(line "$out" BLOCKED_BY)|$(printf '%s\n' "$out" | tail -1)"

state
out="$(run ensure --plan "$empty_plan" --description-file "$work/desc.txt")"
check "plan with no screens: creates none" "|no|no-screens|rc=0" "$(line "$out" DESIGN_STORY)|$(line "$out" CREATED)|$(line "$out" SKIPPED)|$(printf '%s\n' "$out" | tail -1)"
check "plan with no screens: writes nothing" 0 "$(count 'workitem create\|link create')"
echo "D-1" >"$work/state/design"
out="$(run ensure --plan "$empty_plan")"
check "plan with no screens: an existing story is still relinked" "D-1|L-1 L-2|" "$(line "$out" DESIGN_STORY)|$(line "$out" BLOCKED_BY)|$(line "$out" SKIPPED)"

state
out="$(run ensure --plan "$work/missing.md" --description-file "$work/desc.txt")"
check "unreadable plan stops before any write" "1|0" "$(printf '%s\n' "$out" | grep -c 'REASON=no readable component plan')|$(count 'workitem create')"
out="$(run ensure --plan "$plan")"
check "plan time with no description stops" "rc=1|0" "$(printf '%s\n' "$out" | tail -1)|$(count 'workitem create')"

state
run ensure --plan "$plan" --description-file "$work/desc.txt" >/dev/null
out="$(run MOCK_DONE=1 ensure --screens "S-1 S-2")"
check "Done Design story: /stories links the screen stories without error" "D-1|yes|no|S-1 S-2|rc=0" "$(line "$out" DESIGN_STORY)|$(line "$out" DESIGN_DONE)|$(line "$out" CREATED)|$(line "$out" BLOCKS)|$(printf '%s\n' "$out" | tail -1)"
check "Done Design story: no second one is created" 1 "$(count 'workitem create')"
out="$(gate MOCK_DONE=1 S-1)"
check "Done Design story: the screen story is not held" "D-1 PR: done||GATE=PASS" "$(printf '%s\n' "$out" | grep '^D-1 PR')|$(line "$out" DESIGN_BLOCKERS)|$(printf '%s\n' "$out" | tail -1)"

if [ "$failures" -eq 0 ]; then echo "PASS: design-story"; exit 0; fi
echo "FAIL: $failures design-story case(s) failed"; exit 1
