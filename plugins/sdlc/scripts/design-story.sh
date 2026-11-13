#!/usr/bin/env bash
# design-story.sh <EPIC> find
# design-story.sh <EPIC> ensure --description-file <file> [--screens "<KEY> ..."]
#                               [--context <project-context.md>] [--library-label <label>]
#
# The Epic's high-fidelity design story (refs/design-workflow.md "The design story"): one story
# labelled `Design` under the Epic, blocked by every library story and blocking every UI screen
# story, so a screen story cannot start before its final boards exist. A person closes it; it is
# never labelled AI-Ready and never implemented by /auto (dep-gate.sh refuses it).
#
#   find    reads only. Prints the story, whether it is Done, and any second Design story.
#   ensure  idempotent: reuses the Epic's Design story, creates it only when there is none, then
#           adds the Blocks links that are missing. Run it again after new screen stories exist.
#
# acli direction: `link create --out <BLOCKED> --in <BLOCKER>`. The success message prints the
# pair backwards, so the links are read back from `view --fields issuelinks`, where a blocker is
# an `inwardIssue` and a blocked story an `outwardIssue`.
#
# Output (greppable):
#   DESIGN_STORY=<key, empty when there is none>
#   DESIGN_DONE=yes|no
#   EXTRA=<other Design-labelled children; never created here, a person removes them>
#   CREATED=yes|no                 ensure only
#   BLOCKED_BY=<library keys>      ensure only, as read back
#   BLOCKS=<screen keys>           ensure only, as read back
#   RESULT=ok                      exit 0
#   REASON=<why> + RESULT=stop     exit 1 (nothing more was written after the failing step)
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
usage='usage: design-story.sh <EPIC> find | ensure --description-file <file> [--screens "<KEY> ..."] [--context <file>] [--library-label <label>]'
epic="${1:?$usage}"
action="${2:?$usage}"
shift 2

DESIGN_LABEL="Design"
CTX=".claude/project/project-context.md"; LIB_LABEL=""; DESC=""; SCREENS=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --description-file) DESC="${2:-}"; shift 2 ;;
    --screens)          SCREENS="${2:-}"; shift 2 ;;
    --context)          CTX="${2:-}"; shift 2 ;;
    --library-label)    LIB_LABEL="${2:-}"; shift 2 ;;
    *) echo "design-story.sh: unknown argument '$1'" >&2; exit 2 ;;
  esac
done
case "$action" in find|ensure) ;; *) echo "$usage" >&2; exit 2 ;; esac

stop() { echo "REASON=$1"; echo "RESULT=stop"; exit 1; }
guard() {
  local err
  err="$(bash "$here/jira-site-guard.sh" 2>&1)" || stop "jira-site-guard: ${err:-unknown failure}"
}
is_key() { printf '%s' "$1" | grep -qE '^[A-Za-z][A-Za-z0-9]*-[0-9]+$'; }
has_word() { case " $1 " in *" $2 "*) return 0 ;; *) return 1 ;; esac; }

is_key "$epic" || stop "'$epic' is not a Jira key"

keys_of() {
  local json
  json="$(acli jira workitem search --jql "$1" --json 2>/dev/null)" || return 1
  printf '%s' "$json" | jq -r '[.[]?.key // empty] | join(" ")' 2>/dev/null
}

guard
found="$(keys_of "parent = $epic AND labels = \"$DESIGN_LABEL\" ORDER BY created ASC")" \
  || stop "cannot list the Design stories of $epic (cannot verify)"
design="${found%% *}"
extra=""
[ "$found" != "$design" ] && extra="${found#* }"

design_done=no
if [ -n "$design" ]; then
  hit="$(keys_of "key = $design AND statusCategory = Done")" || stop "cannot read the status of $design"
  [ -n "$hit" ] && design_done=yes
fi

if [ "$action" = find ]; then
  echo "DESIGN_STORY=$design"
  echo "DESIGN_DONE=$design_done"
  echo "EXTRA=$extra"
  echo "RESULT=ok"
  exit 0
fi

if [ -z "$LIB_LABEL" ] && [ -f "$CTX" ]; then
  LIB_LABEL="$(grep -i -m1 -E '^\|[[:space:]]*Library label[[:space:]]*\|' "$CTX" \
    | sed -E 's/^\|[^|]*\|[[:space:]]*([^|]*[^|[:space:]])?[[:space:]]*\|.*/\1/' | tr -d '`' || true)"
fi
LIB_LABEL="${LIB_LABEL:-Library}"
case "$LIB_LABEL" in *[!A-Za-z0-9_-]*) stop "unusable library label '$LIB_LABEL'" ;; esac

for s in $SCREENS; do
  is_key "$s" || stop "'$s' in --screens is not a Jira key"
done

libraries="$(keys_of "parent = $epic AND labels = \"$LIB_LABEL\" ORDER BY created ASC")" \
  || stop "cannot list the library stories of $epic (cannot verify)"

created=no
if [ -z "$design" ]; then
  [ -n "$DESC" ] && [ -r "$DESC" ] || stop "no Design story under $epic and no readable --description-file to create one"
  guard
  design="$(acli jira workitem create \
    --project "${epic%-*}" \
    --type "Story" \
    --parent "$epic" \
    --summary "High-fidelity designs for $epic (final boards from the bundle)" \
    --description-file "$DESC" \
    --label "$DESIGN_LABEL" \
    --json 2>/dev/null | jq -r '.key // empty' 2>/dev/null)"
  is_key "$design" || stop "could not create the Design story under $epic (acli create refused or failed) — propose it in an Epic comment instead"
  attached="$(keys_of "parent = $epic AND key = $design")" || stop "cannot verify that $design is under $epic"
  [ "$attached" = "$design" ] || stop "$design was created but is not a child of $epic — fix its parent by hand"
  created=yes
fi
echo "DESIGN_STORY=$design"
echo "DESIGN_DONE=$design_done"
echo "EXTRA=$extra"
echo "CREATED=$created"

read_links() {
  local json
  json="$(acli jira workitem view "$design" --fields issuelinks --json 2>/dev/null)" || return 1
  printf '%s' "$json" | jq -r --arg side "$1" \
    '[.fields.issuelinks[]? | select(.type.name == "Blocks") | .[$side].key // empty] | join(" ")' 2>/dev/null
}
blocked_by="$(read_links inwardIssue)" || stop "cannot read the links of $design"
blocks="$(read_links outwardIssue)" || stop "cannot read the links of $design"

link() {
  guard
  acli jira workitem link create --out "$1" --in "$2" --type Blocks --yes >/dev/null 2>&1 \
    || stop "could not link $2 blocks $1"
}

for lib in $libraries; do
  [ "$lib" = "$design" ] && continue
  has_word "$blocked_by" "$lib" || link "$design" "$lib"
done
for s in $SCREENS; do
  [ "$s" = "$design" ] && continue
  has_word "$libraries" "$s" && stop "$s is a library story — the Design story cannot block it (it would block itself)"
  has_word "$blocks" "$s" || link "$s" "$design"
done

blocked_by="$(read_links inwardIssue)" || stop "cannot read back the links of $design"
blocks="$(read_links outwardIssue)" || stop "cannot read back the links of $design"
echo "BLOCKED_BY=$blocked_by"
echo "BLOCKS=$blocks"

missing=""
for lib in $libraries; do
  [ "$lib" = "$design" ] && continue
  has_word "$blocked_by" "$lib" || missing="${missing:+$missing }$lib"
done
for s in $SCREENS; do
  [ "$s" = "$design" ] && continue
  has_word "$blocks" "$s" || missing="${missing:+$missing }$s"
done
[ -n "$missing" ] && stop "links not read back on $design for: $missing — check the direction in Jira (blocks / is blocked by)"
echo "RESULT=ok"
