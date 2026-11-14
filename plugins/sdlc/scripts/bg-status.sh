#!/usr/bin/env bash
# bg-status.sh — one status line per story for background /sdlc:auto runs. No LLM.
# Usage: bg-status.sh KEY...
#
# Line: KEY verdict=<V> reason=<r> session=<id|-> state=<s|-> idle_min=<N|-> jira=<status|-> \
#       pr=<#N:STATE[:draft]|-> checks=<none|pending|failing|passing|-> needs_you=yes|no needs_heading=yes|no \
#       [sessions=<n>] [duplicates=<id,id>] [question=<header: first question, one line, cut at QUESTION_MAX>]
# `sessions=` is only present when more than one session belongs to the story (a resume chain).
# `duplicates=` lists the full ids of the live sessions when reason=duplicate-sessions.
# `question=` is the last field and only present when the run is blocked on a question; its value
# has spaces and runs to the end of the line.
#
# A resume creates a new session id, gives the session a new name and can change its cwd, so the
# story's session is the newest of every background entry that belongs to it. An entry belongs when
# its name holds the key (any case, whole key), its cwd holds `sdlc-<KEY>` or `/<KEY>`, or its
# transcript names the key in the first user prompt or in a tool call (`/sdlc:auto <KEY>`,
# `run-bg.sh <KEY>`, `feat/<KEY>`, `fix/<KEY>`). Newest is the latest transcript write, else
# startedAt; a live (working/busy) entry wins a tie.
#
# Verdict (first match wins):
#   DONE         Jira status is the `Pipeline done status` of project-context (default Done), or the PR is merged.
#   NEEDS_HUMAN  two live sessions belong to the story (reason=duplicate-sessions, a person stops one),
#                the last assistant message starts with 'NEEDS YOU:', the PR body has a 'Needs a human'
#                heading, the session is blocked/waiting on an unanswered AskUserQuestion, or the run
#                has gone quiet with an open PR (draft, failing checks, or ready to merge).
#   NO_SESSION   no session of the story and no PR.
#   STALLED      session blocked/waiting with no pending question, or no transcript write for
#                STALL_MIN minutes.
#   RUNNING      everything else.
# The session state is not trusted: a run can end its turn with a draft PR while the state still
# reads `working` and Jira stays To Do. The transcript and the PR decide.
# "checks=none" means the PR has no checks at all (some repos have no CI), never "waiting".
# `claude agents --json` carries two fields, `state` and `status`, and either can be null; blocked or
# waiting in either one counts. The transcript sits under the encoding of the session's own cwd (a
# story run's worktree, `/` and `.` both become `-`), not the repo root.
#
# Env: STALL_MIN (default 25), QUIET_MIN (default 3, quiet time before an open PR counts as handed off),
#      QUESTION_MAX (default 200, characters of question text printed), BG_STATUS_NOW (epoch override for tests).
set -uo pipefail

stall_min="${STALL_MIN:-25}"
quiet_min="${QUIET_MIN:-3}"
question_max="${QUESTION_MAX:-200}"
here="$(cd "$(dirname "$0")" && pwd)"

[ "$#" -ge 1 ] || { echo "usage: bg-status.sh KEY..." >&2; exit 2; }

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root" || exit 1

now="${BG_STATUS_NOW:-$(date +%s)}"
agents_json="$(claude agents --json --all 2>/dev/null)"
printf '%s' "$agents_json" | jq -e 'type=="array"' >/dev/null 2>&1 || agents_json='[]'

mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null; }
flat() { printf '%s' "${1:-}" | tr -s '[:space:]' '_' | sed 's/_$//'; }

done_status="$(awk -F'|' 'tolower($2) ~ /^[ \t]*pipeline done status[ \t]*$/ { v=$3; gsub(/^[ \t`]+|[ \t`]+$/, "", v); print v; exit }' .claude/project/project-context.md 2>/dev/null)"
done_status="$(flat "${done_status:-Done}")"

jira_guard_ok=0
bash "$here/jira-site-guard.sh" >/dev/null 2>&1 && jira_guard_ok=1

# transcript_of <session id> <cwd>: the session's transcript path, empty when there is none.
transcript_of() {
  local sid="$1" slug f
  [ -n "$sid" ] || return 0
  slug="$(printf '%s' "${2:-$root}" | sed 's/[^A-Za-z0-9]/-/g')"
  f="$HOME/.claude/projects/$slug/$sid.jsonl"
  [ -f "$f" ] && { printf '%s' "$f"; return 0; }
  for f in "$HOME"/.claude/projects/*/"$sid".jsonl; do [ -f "$f" ] && { printf '%s' "$f"; return 0; }; done
  return 0
}

# One row per background entry: index, live, startedAt (epoch seconds), session id, transcript, its mtime.
us=$'\037'
sessions=""
while IFS="$us" read -r s_idx s_live s_started s_sid s_cwd; do
  [ -n "$s_idx" ] || continue
  s_t="$(transcript_of "$s_sid" "$s_cwd")"
  s_mt=""
  [ -n "$s_t" ] && s_mt="$(mtime "$s_t")"
  sessions="$sessions$s_idx$us$s_live$us$s_started$us$s_sid$us$s_t$us$s_mt"$'\n'
done <<EOF
$(printf '%s' "$agents_json" | jq -r '
  to_entries[] | select(.value | type == "object") | select((.value.kind // "background") == "background")
  | .key as $i | .value
  | [ $i,
      (if ([.state, .status] | any(. == "working" or . == "busy" or . == "running")) then 1 else 0 end),
      ((.startedAt // 0) | if type == "number" then (if . > 100000000000 then . / 1000 else . end | floor) else 0 end),
      (.sessionId // ""), (.cwd // "") ] | map(tostring) | join("\u001f")')
EOF

# mentions_key <transcript> <key regex>: the first user prompt or a tool call names the story.
mentions_key() {
  local t="$1" edge='($|[^A-Za-z0-9])' first call
  first="$(jq -rn 'first(inputs | select(.type=="user" and .isMeta != true) | .message.content
    | if type=="string" then . elif type=="array" then [.[] | select(.type=="text") | .text] | join("\n") else "" end
    | select(length>0)) // ""' "$t" 2>/dev/null)"
  printf '%s\n' "$first" | grep -qiE "(^|[^A-Za-z0-9])$2$edge" && return 0
  # A run started for another story can touch this one's branch; it is not this story's run.
  printf '%s\n' "$first" | grep -qE '(<command-args>[[:space:]]*|^/[^[:space:]]+[[:space:]]+)[A-Za-z][A-Za-z0-9]*-[0-9]+' && return 1
  call="(/sdlc:auto +|run-bg\\.sh +[\\\\\"']*|(feat|fix)/)$2$edge"
  grep -iE -- "$call" "$t" 2>/dev/null | jq -en --arg re "$call" \
    'any(inputs | select(.type=="assistant") | .message.content[]? | select(.type=="tool_use") | (.input | tojson); test($re; "i"))' >/dev/null 2>&1
}

status_for() {
  local key="$1" entry sid state cwd tpath age last jira pr_json pr_num pr_state pr_draft pr_body checks
  local blocked="" question=""
  local needs_you=no needs_heading=no verdict reason="" pr_label="-" prefix
  local kre named cands="" matched=0 live_n=0 dups="" best idx live started s t mt act

  kre="$(printf '%s' "$key" | sed 's/[][\.*^$+?(){}|]/\\&/g')"
  named=" $(printf '%s' "$agents_json" | jq -r --arg re "(^|[^A-Za-z0-9])$kre(\$|[^A-Za-z0-9])" --arg cre "(sdlc-|/)$kre(\$|[^A-Za-z0-9])" '
    [to_entries[] | select(.value | type == "object")
     | select(((.value.name // "") | tostring | test($re; "i")) or ((.value.cwd // "") | tostring | test($cre; "i")))
     | .key] | join(" ")') "
  while IFS="$us" read -r idx live started s t mt; do
    [ -n "$idx" ] || continue
    case "$named" in
      *" $idx "*) ;;
      *) { [ -n "$t" ] && mentions_key "$t" "$kre"; } || continue ;;
    esac
    act="${mt:-$started}"
    cands="$cands$act $live $idx ${s:--}"$'\n'
  done <<EOF
$sessions
EOF

  entry=""
  if [ -n "$cands" ]; then
    matched="$(printf '%s' "$cands" | grep -c .)"
    best="$(printf '%s' "$cands" | sort -k1,1n -k2,2n | tail -n 1)"
    idx="$(printf '%s' "$best" | awk '{print $3}')"
    entry="$(printf '%s' "$agents_json" | jq -c --argjson i "$idx" '.[$i] // empty')"
    live_n="$(printf '%s' "$cands" | awk '$2==1' | grep -c .)"
    [ "$live_n" -ge 2 ] && dups="$(printf '%s' "$cands" | sort -k1,1n | awk '$2==1 {print $4}' | paste -sd, -)"
  fi
  sid="" state="" cwd=""
  if [ -n "$entry" ]; then
    sid="$(printf '%s' "$entry" | jq -r '.sessionId // empty')"
    state="$(printf '%s' "$entry" | jq -r '.status // .state // empty')"
    blocked="$(printf '%s' "$entry" | jq -r '[.state, .status] | map(select(. == "blocked" or . == "waiting")) | first // empty')"
    cwd="$(printf '%s' "$entry" | jq -r '.cwd // empty')"
  fi

  tpath="" age=""
  if [ -n "$sid" ]; then
    tpath="$(transcript_of "$sid" "$cwd")"
    if [ -n "$tpath" ] && [ -f "$tpath" ]; then
      mt="$(mtime "$tpath")"
      [ -n "$mt" ] && age=$(( (now - mt) / 60 ))
      last="$(jq -rs '[.[] | select(.type=="assistant") | [.message.content[]? | select(.type=="text") | .text] | join("\n") | select(length>0)] | last // ""' "$tpath" 2>/dev/null)"
      case "$last" in 'NEEDS YOU:'*) needs_you=yes ;; esac
      # An answered question is followed by a user entry holding its tool_result.
      question="$(jq -rs '
        [.[] | select(.type=="assistant" or .type=="user")] | last
        | select(.type=="assistant")
        | (.message.content | if type=="array" then last else empty end)
        | select(.type=="tool_use" and .name=="AskUserQuestion")
        | (.input.questions // []) as $q
        | ([($q[0].header // ""), ($q[0].question // "")] | map(select(length>0)) | join(": ")) as $t
        | (if ($t|length)>0 then $t else "question pending" end)
          + (if ($q|length)>1 then " (+\(($q|length)-1) more)" else "" end)' "$tpath" 2>/dev/null \
        | tr -s '[:space:]' ' ' | sed 's/^ //; s/ $//')"
      [ "${#question}" -gt "$question_max" ] && question="${question:0:question_max}..."
    fi
  fi

  jira="-"
  if [ "$jira_guard_ok" = 1 ]; then
    jira="$(flat "$(acli jira workitem view "$key" --fields status --json 2>/dev/null | jq -r '.fields.status.name // empty')")"
    [ -z "$jira" ] && jira="-"
  fi

  pr_json="[]"
  for prefix in feat fix; do
    pr_json="$(gh pr list --head "$prefix/$key" --state all --json number,state,isDraft,body,statusCheckRollup 2>/dev/null)"
    printf '%s' "$pr_json" | jq -e 'type=="array" and length>0' >/dev/null 2>&1 && break
    pr_json="[]"
  done

  pr_num="" pr_state="" pr_draft="false" pr_body="" checks="-"
  if [ "$pr_json" != "[]" ]; then
    local pr; pr="$(printf '%s' "$pr_json" | jq -c 'sort_by(.number) | last')"
    pr_num="$(printf '%s' "$pr" | jq -r '.number')"
    pr_state="$(printf '%s' "$pr" | jq -r '.state')"
    pr_draft="$(printf '%s' "$pr" | jq -r '.isDraft')"
    pr_body="$(printf '%s' "$pr" | jq -r '.body // ""')"
    pr_label="#$pr_num:$pr_state"
    [ "$pr_draft" = true ] && pr_label="$pr_label:draft"
    checks="$(printf '%s' "$pr" | jq -r '
      (.statusCheckRollup // []) as $c
      | if ($c|length)==0 then "none"
        elif any($c[]; (.conclusion // .state // "") | test("^(FAILURE|ERROR|CANCELLED|TIMED_OUT|ACTION_REQUIRED|STARTUP_FAILURE)$")) then "failing"
        elif any($c[]; ((.status // "COMPLETED") != "COMPLETED") or ((.state // "") | test("^(PENDING|EXPECTED)$"))) then "pending"
        else "passing" end')"
    printf '%s\n' "$pr_body" | grep -qiE '^#{1,6}[[:space:]]+needs a human[[:space:]]*$' && needs_heading=yes
  fi

  local quiet=0
  [ -n "$age" ] && [ "$age" -ge "$quiet_min" ] && quiet=1
  [ -z "$sid" ] && quiet=1

  if [ "$jira" = "$done_status" ] || [ "$pr_state" = MERGED ]; then
    verdict=DONE; reason=$([ "$pr_state" = MERGED ] && echo merged || echo jira-done)
  elif [ "$live_n" -ge 2 ]; then
    verdict=NEEDS_HUMAN; reason="duplicate-sessions"
  elif [ "$needs_you" = yes ]; then
    verdict=NEEDS_HUMAN; reason="last-message"
  elif [ "$needs_heading" = yes ]; then
    verdict=NEEDS_HUMAN; reason="pr-heading"
  elif [ -z "$sid" ] && [ -z "$pr_num" ]; then
    verdict=NO_SESSION; reason="no-session-no-pr"
  elif [ -n "$blocked" ] && [ -n "$question" ]; then
    verdict=NEEDS_HUMAN; reason="question"
  elif [ -n "$blocked" ]; then
    verdict=STALLED; reason="state-$blocked"
  elif [ "$pr_state" = OPEN ] && [ "$quiet" = 1 ] && [ "$pr_draft" = true ]; then
    verdict=NEEDS_HUMAN; reason="draft-pr"
  elif [ "$pr_state" = OPEN ] && [ "$quiet" = 1 ] && [ "$checks" = failing ]; then
    verdict=NEEDS_HUMAN; reason="checks-failing"
  elif [ "$pr_state" = OPEN ] && [ "$quiet" = 1 ] && [ "$checks" != pending ]; then
    verdict=NEEDS_HUMAN; reason="ready-to-merge"
  elif [ -n "$age" ] && [ "$age" -ge "$stall_min" ]; then
    verdict=STALLED; reason="no-write-${age}m"
  else
    verdict=RUNNING; reason="active"
    [ "$pr_state" = OPEN ] && [ "$checks" = pending ] && reason="checks-pending"
  fi

  local tail=""
  [ "$matched" -gt 1 ] && tail=" sessions=$matched"
  [ "$reason" = duplicate-sessions ] && tail="$tail duplicates=$dups"
  [ "$reason" = question ] && tail="$tail question=$question"
  printf '%s verdict=%s reason=%s session=%s state=%s idle_min=%s jira=%s pr=%s checks=%s needs_you=%s needs_heading=%s%s\n' \
    "$key" "$verdict" "$reason" "${sid:--}" "${state:--}" "${age:--}" "$jira" "$pr_label" "$checks" "$needs_you" "$needs_heading" "$tail"
}

for k in "$@"; do status_for "$k"; done
