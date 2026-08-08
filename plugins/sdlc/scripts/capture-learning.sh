#!/usr/bin/env bash
# capture-learning.sh — NA-98. Write ONE learning capture into the gitignored staging area.
#
# usage: capture-learning.sh rule   <agent-or-shared>/<rule-id> <STORY-KEY> <payload-file>
#        capture-learning.sh review <STORY-KEY> <YYYY-MM-DD> <round>       [<payload-file>|-]
#        capture-learning.sh --print-root
#
# NA-103: <payload-file> is REQUIRED for `rule` (no bare/omitted/'-' form) — the 7-field rule
# schema (trigger/rule/evidence, or a counter-only uses/evidence update) can only come from a
# payload; a bare write can no longer produce anything but a refused, malformed capture. `review`
# keeps its optional payload — a review with no findings legitimately has nothing to add.
#
# Prints CAPTURED=<path> on success. Reads exactly one environment variable, SDLC_CAPTURE_ROOT.
# Never reads stdin.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
. "$here/frontmatter-lib.sh"
# shellcheck source=/dev/null
. "$here/memory-root.sh"

die() { printf '%s\n' "$1" >&2; exit 1; }

resolve_capture_root() {
  if [ -n "${SDLC_CAPTURE_ROOT:-}" ]; then
    printf '%s\n' "$SDLC_CAPTURE_ROOT"
    return 0
  fi
  local root
  root="$(sdlc_memory_root)" \
    || die "capture-learning.sh: cannot resolve the memory root (see the memory-root.sh error above); wrote nothing"
  printf '%s\n' "$root/captured"
}

ensure_capture_root() {
  local root="$1"
  mkdir -p "$root/rules" "$root/reviews" 2>/dev/null \
    || die "capture-learning.sh: cannot create staging root '$root' — check permissions and that no path segment is a file; wrote nothing"
  [ -w "$root" ] \
    || die "capture-learning.sh: staging root '$root' is not writable; wrote nothing"
  [ -f "$root/.gitignore" ] || printf '*\n!.gitignore\n' > "$root/.gitignore" \
    || die "capture-learning.sh: cannot write the ignore marker in '$root'; wrote nothing"
}

if [ "${1:-}" = "--print-root" ]; then
  root="$(resolve_capture_root)" || exit 1
  ensure_capture_root "$root"
  printf '%s\n' "$root"
  exit 0
fi

kind="${1:-}"
[ -n "$kind" ] || die "usage: capture-learning.sh rule <agent-or-shared>/<rule-id> <STORY-KEY> <payload-file>
       capture-learning.sh review <STORY-KEY> <YYYY-MM-DD> <round> [<payload-file>|-]"

payload_fm() {                     # $1 = payload path or empty; $2 = key; $3 = default
  [ -n "$1" ] || { printf '%s' "$3"; return 0; }
  local v; v="$(extract_fm "$1" | parse_frontmatter | sed -n "s/^FIELD:$2=//p" | head -1)"
  [ -n "$v" ] && printf '%s' "$v" || printf '%s' "$3"
}
as_list() {                        # csv -> [a, b]  (empty -> [])
  [ -n "$1" ] && printf '[%s]' "$(printf '%s' "$1" | sed 's/,/, /g')" || printf '[]'
}
payload_body() {                   # everything after the closing --- , or the whole file if unfenced
  [ -n "$1" ] || return 0
  head -1 "$1" | grep -q '^---[[:space:]]*$' \
    && awk 'NR==1&&/^---[[:space:]]*$/{o=1;next} o&&!d&&/^---[[:space:]]*$/{d=1;next} d' "$1" \
    || cat "$1"
}
write_atomic() {                   # $1 = dest, $2 = content
  local dest="$1" content="$2" t="$1.tmp.$$"
  printf '%s\n' "$content" > "$t" && mv "$t" "$dest"
}
validate_story_key() {             # $1 = story key; dies on a shape that isn't a real Jira key
  printf '%s' "$1" | grep -qE '^[A-Z][A-Z0-9]*-[0-9]+$' \
    || die "capture-learning.sh: story key '$1' is not <PROJECT>-<N> (e.g. AB-1); wrote nothing"
}
payload_has_field() {              # $1 = payload path or empty; $2 = key
  [ -n "$1" ] || return 1
  has_field "$(extract_fm "$1" | parse_frontmatter)" "$2"
}
csv_len() {                        # $1 = comma-joined list (possibly empty) -> item count
  [ -n "$1" ] && printf '%s' "$1" | awk -F',' '{print NF}' || printf '0'
}
valid_evidence_item() {            # $1 = one evidence token -> 0 if Jira key | PR#n | 7-40 char SHA
  # [A-Z0-9]* (not +) — must accept a single-letter Jira project key (e.g. "A-1"), same as
  # validate_story_key below; check-frontmatter.sh's copy must agree (NA-103 Minor 6).
  [[ "$1" =~ ^[A-Z][A-Z0-9]*-[0-9]+$ ]] && return 0
  [[ "$1" =~ ^PR#[0-9]+$ ]] && return 0
  [[ "$1" =~ ^[0-9a-f]{7,40}$ ]] && return 0
  return 1
}
is_counter_only_payload() {        # $1 = payload path or empty -> 0 if a counter-only update
  # NA-103: `agent` presence is deliberately NOT part of this signature — a shared/ counter-only
  # payload legitimately carries `agent:` (Important 3 fix, the >= 2 agents check is now
  # unconditional). `trigger`/`rule` absence is what actually distinguishes "counter-only" from "a
  # full capture" — the T3g8-style smuggle attempt (agent + trigger, no rule) is still excluded
  # here purely by its `trigger:` field, then correctly falls through to full validation.
  payload_has_field "$1" uses && ! payload_has_field "$1" rule && ! payload_has_field "$1" trigger
}
validate_rule_payload_schema() {   # $1 = payload path or empty; dies on a non-7-field-shaped payload
  local payload="$1" trig trig_n rule_val evidence_val evidence_n uses_val item IFS_OLD
  trig="$(payload_fm "$payload" trigger "")"
  trig_n="$(csv_len "$trig")"
  { [ "$trig_n" -ge 1 ] && [ "$trig_n" -le 6 ]; } \
    || die "capture-learning.sh: payload trigger must have 1-6 items, got $trig_n; wrote nothing"

  rule_val="$(payload_fm "$payload" rule "")"
  [ -n "$rule_val" ] \
    || die "capture-learning.sh: payload rule is empty; wrote nothing"
  [ "${#rule_val}" -le 200 ] \
    || die "capture-learning.sh: payload rule exceeds 200 chars (${#rule_val}); wrote nothing"

  # NA-103 (PR #237 review, Important 2): uses was validated on the counter-only path but not
  # here — a full-rule payload could write `uses: banana` or `uses: -5` successfully, then break
  # check-frontmatter.sh's hard-fail on the SAME values once promoted. Same check, both paths.
  uses_val="$(payload_fm "$payload" uses 0)"
  [[ "$uses_val" =~ ^[0-9]+$ ]] \
    || die "capture-learning.sh: payload uses '$uses_val' is not a non-negative integer; wrote nothing"

  evidence_val="$(payload_fm "$payload" evidence "")"
  evidence_n="$(csv_len "$evidence_val")"
  [ "$evidence_n" -ge 1 ] \
    || die "capture-learning.sh: payload evidence must have >= 1 item, got $evidence_n; wrote nothing"
  IFS_OLD="$IFS"; IFS=','
  for item in $evidence_val; do
    valid_evidence_item "$item" \
      || { IFS="$IFS_OLD"; die "capture-learning.sh: payload evidence item '$item' is not a Jira key, PR#n, or 7-40 char SHA; wrote nothing"; }
  done
  IFS="$IFS_OLD"
}
validate_counter_only_payload() { # $1 = payload path; dies on a malformed counter-only update
  # A counter-only update is exempt from trigger/rule content, but `uses`/`evidence` are the ONLY
  # content it carries — leaving them unchecked let garbage (uses: not-a-number, an unrecognised
  # evidence token) through untouched, defeating AC1's "malformed capture cannot be created" for
  # this whole branch (NA-103 Important 3).
  local payload="$1" uses_val evidence_val evidence_n item IFS_OLD
  uses_val="$(payload_fm "$payload" uses "")"
  [[ "$uses_val" =~ ^[0-9]+$ ]] \
    || die "capture-learning.sh: counter-only payload uses '$uses_val' is not a non-negative integer; wrote nothing"

  evidence_val="$(payload_fm "$payload" evidence "")"
  evidence_n="$(csv_len "$evidence_val")"
  [ "$evidence_n" -ge 1 ] \
    || die "capture-learning.sh: counter-only payload evidence must have >= 1 item, got $evidence_n; wrote nothing"
  IFS_OLD="$IFS"; IFS=','
  for item in $evidence_val; do
    valid_evidence_item "$item" \
      || { IFS="$IFS_OLD"; die "capture-learning.sh: counter-only payload evidence item '$item' is not a Jira key, PR#n, or 7-40 char SHA; wrote nothing"; }
  done
  IFS="$IFS_OLD"
}

root="$(resolve_capture_root)" || exit 1
ensure_capture_root "$root"
now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

case "$kind" in
  rule)
    target="${2:-}"; story="${3:-}"; payload="${4:-}"
    [ -n "$target" ] && [ -n "$story" ] || die "capture-learning.sh: rule needs <agent-or-shared>/<rule-id> <STORY-KEY> <payload-file>"
    validate_story_key "$story"
    # NA-103 Critical 2: a payload is now REQUIRED for `rule` — the 7-field schema (or a
    # counter-only uses/evidence update) can only come from one, so a bare/omitted/'-' write can
    # no longer produce anything but a refused, malformed capture. refs/domain-agent-handoff.md's
    # own-domain usage line and this script's usage header agree with this.
    [ -n "$payload" ] \
      || die "capture-learning.sh: rule needs a <payload-file> — every rule capture must carry real trigger/rule/evidence content (or a counter-only uses/evidence update); wrote nothing"
    [ "$payload" = "-" ] \
      && die "capture-learning.sh: rule no longer accepts '-' (explicit no-payload) — a rule capture always needs real content; wrote nothing"
    [ -r "$payload" ] || die "capture-learning.sh: payload file '$payload' is missing or unreadable; wrote nothing"
    case "$target" in
      */*) : ;;
      *) die "capture-learning.sh: rule target '$target' needs <agent-or-shared>/<rule-id>; wrote nothing" ;;
    esac
    dir="${target%%/*}"; rid="${target#*/}"
    printf '%s' "$rid" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$' \
      || die "capture-learning.sh: rule id '$rid' is not kebab-case; wrote nothing"
    valid=" shared "
    for a in "$here/../agents/"*.md; do
      n="$(basename "$a" .md)"; [ "$n" = "principal-engineer" ] || valid="$valid$n "
    done
    case "$valid" in *" $dir "*) : ;; *) die "capture-learning.sh: unknown target dir '$dir'; wrote nothing" ;; esac
    counter_only=0
    is_counter_only_payload "$payload" && counter_only=1
    # NA-103 Important 3: the >= 2 agents rule for shared/ is now UNCONDITIONAL — a counter-only
    # update no longer skips it. The exemption only ever covered trigger/rule CONTENT (the target's
    # own promoted file already carries the real agent list); it never had to also waive the
    # agent-list format check, and doing so let `agent: []` through unnoticed.
    if [ "$dir" = "shared" ]; then
      agents="$(payload_fm "$payload" agent "")"
      agents_n="$(csv_len "$agents")"
      [ "$agents_n" -ge 2 ] \
        || die "capture-learning.sh: agents/shared/ capture needs >= 2 agents in the payload's 'agent:' list (got [$agents]); wrote nothing"
    else
      agents="$dir"
    fi
    # 7-field rule schema (trigger/rule/evidence) is validated at write time — a counter-only
    # update (uses+evidence only, re-incrementing an already-promoted rule) is exempt from the
    # trigger/rule CONTENT check, since it deliberately carries none of its own (distill merges it
    # into the target), but its own uses/evidence content is still validated either way.
    if [ "$counter_only" -eq 0 ]; then
      validate_rule_payload_schema "$payload"
    else
      validate_counter_only_payload "$payload"
    fi
    dest="$root/rules/$story--$rid.md"
    content="$(
      printf -- '---\n'
      printf 'id: %s\n' "$rid"
      printf 'agent: %s\n' "$(as_list "$agents")"
      printf 'trigger: %s\n' "$(as_list "$(payload_fm "$payload" trigger "")")"
      printf 'rule: %s\n' "$(payload_fm "$payload" rule '""')"
      printf 'evidence: %s\n' "$(as_list "$(payload_fm "$payload" evidence "")")"
      printf 'uses: %s\n' "$(payload_fm "$payload" uses 0)"
      printf 'status: captured\n'
      printf 'captured: %s\n' "$now"
      printf 'story: %s\n' "$story"
      printf 'origin: %s\n' "$(payload_fm "$payload" origin domain-agent)"
      printf 'promote-target: agents/%s/%s.md\n' "$dir" "$rid"
      printf -- '---\n'
      payload_body "$payload"
    )"
    write_atomic "$dest" "$content" \
      || die "capture-learning.sh: failed writing '$dest'; wrote nothing"
    ;;
  review)
    story="${2:-}"; rdate="${3:-}"; round="${4:-1}"; payload="${5:-}"
    [ -n "$story" ] && [ -n "$rdate" ] || die "capture-learning.sh: review needs <STORY-KEY> <YYYY-MM-DD> <round>"
    validate_story_key "$story"
    printf '%s' "$rdate" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' \
      || die "capture-learning.sh: date '$rdate' is not YYYY-MM-DD; wrote nothing"
    printf '%s' "$round" | grep -qE '^[1-9][0-9]{0,3}$' \
      || die "capture-learning.sh: round '$round' is not a positive integer (1-9999); wrote nothing"
    [ "$payload" = "-" ] && payload=""
    [ -n "$payload" ] && [ ! -r "$payload" ] && die "capture-learning.sh: payload file '$payload' is missing or unreadable; wrote nothing"
    [ "$round" -gt 1 ] && sfx="-r$round" || sfx=""
    stem="$rdate-$story$sfx"; dest="$root/reviews/$stem.md"
    content="$(
      printf -- '---\n'
      printf 'story: %s\n' "$story"
      printf 'date: %s\n' "$rdate"
      printf 'domains: %s\n' "$(as_list "$(payload_fm "$payload" domains "")")"
      printf 'root_causes: %s\n' "$(as_list "$(payload_fm "$payload" root_causes "")")"
      printf 'issue_count: %s\n' "$(payload_fm "$payload" issue_count 0)"
      printf 'captured: %s\n' "$now"
      printf 'origin: qa-round\n'
      printf 'promote-target: reviews/%s.md\n' "$stem"
      printf -- '---\n'
      payload_body "$payload"
    )"
    write_atomic "$dest" "$content" \
      || die "capture-learning.sh: failed writing '$dest'; wrote nothing"
    ;;
  *)
    die "capture-learning.sh: unknown kind '$kind' — expected 'rule' or 'review'; wrote nothing"
    ;;
esac

printf 'CAPTURED=%s\n' "$dest"
