#!/usr/bin/env bash
# frontmatter-lib.sh — sourced YAML-frontmatter helpers shared by capture-learning.sh and
# list-captured.sh. Bodies are verbatim copies of collect-memory.sh:17-95, which is pinned
# "No change" by NA-98's spec; do not diverge them without updating both.
# Sourced, never executed: no `set -e`, no top-level side effects.

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
