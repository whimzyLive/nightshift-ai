#!/usr/bin/env bash
# capture-learning.sh — NA-98. Write ONE learning capture into the gitignored staging area.
#
# usage: capture-learning.sh rule   <agent-or-shared>/<rule-id> <STORY-KEY> [<payload-file>|-]
#        capture-learning.sh review <STORY-KEY> <YYYY-MM-DD> <round>       [<payload-file>|-]
#        capture-learning.sh --print-root
#
# Prints CAPTURED=<path> on success. Reads exactly one environment variable, SDLC_CAPTURE_ROOT.
# Never reads stdin.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
. "$here/frontmatter-lib.sh"

die() { printf '%s\n' "$1" >&2; exit 1; }

resolve_capture_root() {
  if [ -n "${SDLC_CAPTURE_ROOT:-}" ]; then
    printf '%s\n' "$SDLC_CAPTURE_ROOT"
    return 0
  fi
  local porcelain main
  porcelain="$(git worktree list --porcelain 2>/dev/null)" \
    || die "capture-learning.sh: 'git worktree list --porcelain' failed — cannot resolve the staging root; wrote nothing"
  printf '%s\n' "$porcelain" | head -3 | grep -q '^bare$' \
    && die "capture-learning.sh: main repository is bare — no primary checkout to capture into; wrote nothing"
  main="$(printf '%s\n' "$porcelain" | sed -n 's/^worktree //p' | head -1)"
  [ -n "$main" ] \
    && printf '%s\n' "$main/.claude/memories/captured" \
    || die "capture-learning.sh: no 'worktree ' entry in git worktree list output; wrote nothing"
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
[ -n "$kind" ] || die "usage: capture-learning.sh rule <agent-or-shared>/<rule-id> <STORY-KEY> [<payload-file>|-]
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

root="$(resolve_capture_root)" || exit 1
ensure_capture_root "$root"
now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

case "$kind" in
  rule)
    target="${2:-}"; story="${3:-}"; payload="${4:-}"
    [ -n "$target" ] && [ -n "$story" ] || die "capture-learning.sh: rule needs <agent-or-shared>/<rule-id> <STORY-KEY>"
    validate_story_key "$story"
    [ "$payload" = "-" ] && payload=""
    [ -n "$payload" ] && [ ! -r "$payload" ] && die "capture-learning.sh: payload file '$payload' is missing or unreadable; wrote nothing"
    dir="${target%%/*}"; rid="${target#*/}"
    printf '%s' "$rid" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$' \
      || die "capture-learning.sh: rule id '$rid' is not kebab-case; wrote nothing"
    valid=" shared "
    for a in "$here/../agents/"*.md; do
      n="$(basename "$a" .md)"; [ "$n" = "principal-engineer" ] || valid="$valid$n "
    done
    case "$valid" in *" $dir "*) : ;; *) die "capture-learning.sh: unknown target dir '$dir'; wrote nothing" ;; esac
    if [ "$dir" = "shared" ]; then
      agents="$(payload_fm "$payload" agent "")"
      counter_only=0
      payload_has_field "$payload" uses && ! payload_has_field "$payload" rule && counter_only=1
      if [ "$counter_only" -eq 0 ]; then
        agents_n=0
        [ -n "$agents" ] && agents_n="$(printf '%s' "$agents" | awk -F',' '{print NF}')"
        [ "$agents_n" -ge 2 ] \
          || die "capture-learning.sh: agents/shared/ capture needs >= 2 agents in the payload's 'agent:' list (got [$agents]); wrote nothing"
      fi
    else
      agents="$dir"
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
      printf 'promote-target: .claude/memories/agents/%s/%s.md\n' "$dir" "$rid"
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
      printf 'promote-target: .claude/memories/reviews/%s.md\n' "$stem"
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
