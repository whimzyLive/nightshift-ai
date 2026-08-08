#!/usr/bin/env bash
set -uo pipefail
shopt -s nullglob

here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
. "$here/memory-root.sh"

agent="${1:-}"
if [ -z "$agent" ]; then
  echo "usage: collect-memory.sh <agent> [<repo-root>]" >&2
  exit 1
fi

explicit_root="${2:-}"
repo_root="$explicit_root"
if [ -z "$repo_root" ]; then
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"
  [ -z "$repo_root" ] && repo_root="$(pwd)"
fi

# mem_roots — newline-delimited, in precedence order.
#   arg2 present -> LEGACY-ONLY (keeps memory-frontmatter.test.sh fixtures hermetic)
#   arg2 absent  -> DUAL: resolved root, then <git-toplevel>/.claude/memories
# The legacy entry is the NA-101 transition shim. NA-102 ships migrate-memory-root.sh (the
# one-shot corpus move) but deliberately does NOT remove this shim — it stays a harmless no-op
# once the tree is empty; removing it is explicitly out of NA-102's scope and left to a
# follow-up story. Unlike list-captured.sh this one correctly uses git-toplevel: the legacy
# corpus is TRACKED, so it is present in every worktree.
mem_roots=""
if [ -n "$explicit_root" ]; then
  mem_roots="$explicit_root/.claude/memories"
else
  # A hasher on the success path can write to stderr while still exiting 0 (e.g. macOS
  # /usr/bin/shasum is Perl and warns on a locale mismatch) — 2>&1 on the success call would
  # contaminate $resolved with that warning text. Only re-invoke with 2>&1 to capture the reason
  # AFTER a plain 2>/dev/null call has already established failure; the resolver is side-effect
  # free on --print-root, so a second call is safe.
  resolver_err=""
  if ! resolved="$(sdlc_memory_root 2>/dev/null)" || [ -z "$resolved" ]; then
    resolver_err="$(sdlc_memory_root 2>&1 >/dev/null)"
    resolved=""
  fi
  if [ -z "$resolved" ]; then
    echo "collect-memory: WARNING — ${resolver_err:-cannot resolve the memory root}; using the legacy in-repo root only" >&2
  elif [ -d "$resolved" ]; then
    mem_roots="$resolved"
  fi
  [ -d "$repo_root/.claude/memories" ] && mem_roots="$mem_roots${mem_roots:+
}$repo_root/.claude/memories"
fi

extract_fm() {
  awk '
    NR==1 && /^---[[:space:]]*$/ { open=1; next }
    NR==1 { exit }
    open && /^---[[:space:]]*$/ { exit }
    open { print }
  ' "$1"
}

parse_frontmatter() {
  awk '
    function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    function unquote(s,    n) {
      s = trim(s)
      n = length(s)
      if (n >= 2 && substr(s, 1, 1) == "\"" && substr(s, n, 1) == "\"") {
        s = substr(s, 2, n - 2)
      }
      return s
    }
    BEGIN { key=""; in_list=0; listval="" }
    {
      line = $0
      if (match(line, /^[A-Za-z_][A-Za-z0-9_-]*:/)) {
        if (key != "" && in_list) { print "FIELD:" key "=" listval }
        colonpos = index(line, ":")
        key = substr(line, 1, colonpos - 1)
        rest = trim(substr(line, colonpos + 1))
        in_list = 0
        listval = ""
        if (rest == "") {
          in_list = 1
        } else if (substr(rest, 1, 1) == "[") {
          inner = rest
          gsub(/^\[|\][ \t]*$/, "", inner)
          inner = trim(inner)
          out = ""
          if (inner != "") {
            n = split(inner, arr, ",")
            for (i = 1; i <= n; i++) {
              v = unquote(trim(arr[i]))
              if (v != "") out = (out == "" ? v : out "," v)
            }
          }
          print "FIELD:" key "=" out
          key = ""
        } else {
          print "FIELD:" key "=" unquote(rest)
          key = ""
        }
      } else if (in_list && match(line, /^[ \t]*-[ \t]?/)) {
        item = line
        sub(/^[ \t]*-[ \t]?/, "", item)
        item = unquote(trim(item))
        if (item != "") listval = (listval == "" ? item : listval "," item)
      }
    }
    END {
      if (key != "" && in_list) print "FIELD:" key "=" listval
    }
  '
}

has_field() {
  printf '%s\n' "$1" | grep -q "^FIELD:${2}="
}

field_value() {
  printf '%s\n' "$1" | sed -n "s/^FIELD:${2}=//p" | head -1
}

list_contains() {
  local list="$1" needle="$2" item
  IFS=',' read -ra items <<< "$list"
  for item in "${items[@]}"; do
    [ "$item" = "$needle" ] && return 0
  done
  return 1
}

csv_to_display() {
  [ -z "$1" ] && return 0
  printf '%s' "$1" | sed 's/,/, /g'
}

emitted_ids=""
id_seen() { printf '%s' "$emitted_ids" | grep -qxF "$1"; }
id_mark() { emitted_ids="$emitted_ids$1
"; }

process_rule_file() {
  local file="$1"
  local fm parsed
  fm="$(extract_fm "$file")"
  [ -z "$fm" ] && return 0
  parsed="$(printf '%s\n' "$fm" | parse_frontmatter)"

  has_field "$parsed" id || return 0
  has_field "$parsed" agent || return 0
  has_field "$parsed" trigger || return 0
  has_field "$parsed" rule || return 0
  has_field "$parsed" status || return 0

  local id agent_list status_val trig rule_val
  id="$(field_value "$parsed" id)"
  agent_list="$(field_value "$parsed" agent)"
  status_val="$(field_value "$parsed" status)"
  trig="$(field_value "$parsed" trigger)"
  rule_val="$(field_value "$parsed" rule)"

  [ -z "$id" ] && return 0
  id_seen "$id" && return 0

  if list_contains "$agent_list" "$agent" && [ "$status_val" = "active" ]; then
    id_mark "$id"
    printf 'RULE %s [%s] %s\n' "$id" "$(csv_to_display "$trig")" "$rule_val"
  fi
}

adr_title() {
  awk '
    NR==1 && /^---[[:space:]]*$/ { open=1; next }
    NR==1 { exit }
    open && /^---[[:space:]]*$/ { open=0; body=1; next }
    body && /^# / { sub(/^# */, ""); print; exit }
  ' "$1"
}

process_adr_file() {
  local file="$1"
  local fm parsed
  fm="$(extract_fm "$file")"
  [ -z "$fm" ] && return 0
  parsed="$(printf '%s\n' "$fm" | parse_frontmatter)"

  has_field "$parsed" status || return 0
  local status_val
  status_val="$(field_value "$parsed" status)"
  [ "$status_val" = "accepted" ] || return 0

  local agents_list=""
  has_field "$parsed" agents && agents_list="$(field_value "$parsed" agents)"

  if [ -n "$agents_list" ] && ! list_contains "$agents_list" "$agent"; then
    return 0
  fi

  local trig nnnn title base
  trig="$(field_value "$parsed" trigger)"
  base="$(basename "$file")"
  nnnn="${base%%-*}"
  title="$(adr_title "$file")"

  printf 'ADR %s [%s] %s\n' "$nnnn" "$(csv_to_display "$trig")" "$title"
}

legacy_banner_done=0

while IFS= read -r mem_root; do
  [ -n "$mem_root" ] || continue

  legacy_file="$mem_root/agents/$agent.md"
  if [ "$legacy_banner_done" -eq 0 ] && [ -f "$legacy_file" ]; then
    printf 'LEGACY\n'
    cat "$legacy_file"
    echo "collect-memory: WARNING — $legacy_file is a v1 flat diary; migrate to <memory-root>/agents/$agent/<rule-id>.md (NA-74)." >&2
    legacy_banner_done=1
  fi

  for d in "$mem_root/agents/$agent" "$mem_root/agents/shared"; do
    [ -d "$d" ] || continue
    for f in "$d"/*.md; do
      process_rule_file "$f"
    done
  done
done <<< "$mem_roots"

adr_dir="$repo_root/docs/adr"
if [ -d "$adr_dir" ]; then
  for f in "$adr_dir"/*.md; do
    [ "$(basename "$f")" = "index.md" ] && continue
    process_adr_file "$f"
  done
fi

exit 0
