#!/usr/bin/env bash
# artifact-contract.sh — see tools/sdlc-analyser/README.md for the extraction rule.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$here/../.." && pwd)"

mode=""
extract_path=""
template_path=""
artifact_path=""
section=""
fence_spec=""

usage() {
  echo "usage:" >&2
  echo "  artifact-contract.sh --extract <path> [--section \"<heading>\"] [--fence <n>[,<n>...]]" >&2
  echo "  artifact-contract.sh --template <path> [--section \"<heading>\"] [--fence <n>[,<n>...]] --artifact <path>" >&2
}

while [ $# -gt 0 ]; do
  case "$1" in
    --extract)
      [ $# -ge 2 ] || { echo "artifact-contract: --extract requires a path" >&2; exit 1; }
      mode="extract"
      extract_path="$2"
      shift 2
      ;;
    --template)
      [ $# -ge 2 ] || { echo "artifact-contract: --template requires a path" >&2; exit 1; }
      mode="diff"
      template_path="$2"
      shift 2
      ;;
    --artifact)
      [ $# -ge 2 ] || { echo "artifact-contract: --artifact requires a path" >&2; exit 1; }
      artifact_path="$2"
      shift 2
      ;;
    --section)
      [ $# -ge 2 ] || { echo "artifact-contract: --section requires a heading" >&2; exit 1; }
      section="$2"
      shift 2
      ;;
    --fence)
      [ $# -ge 2 ] || { echo "artifact-contract: --fence requires an index list" >&2; exit 1; }
      fence_spec="$2"
      shift 2
      ;;
    *)
      echo "artifact-contract: unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [ "$mode" = "extract" ]; then
  [ -z "$template_path" ] && [ -z "$artifact_path" ] || {
    echo "artifact-contract: --extract cannot combine with --template/--artifact" >&2
    exit 1
  }
elif [ "$mode" = "diff" ]; then
  [ -n "$artifact_path" ] || { echo "artifact-contract: --template requires --artifact" >&2; exit 1; }
else
  usage
  exit 1
fi

extract_awk="$(mktemp)"
compare_awk="$(mktemp)"
trap 'rm -f "$extract_awk" "$compare_awk" "${tpl_items:-}" "${tpl_err:-}" "${art_items:-}" "${art_err:-}"' EXIT

# The content-contract extraction rule (verbatim, see README): in file order, a contract item is
# any of heading / field (inside a ```yaml fence or leading frontmatter) / fence info string
# (once per fence) / literal backtick-quoted span classified path|command|ALL-CAPS. Prose is never
# an item. Headings descend into fences (fences are content, not skipped regions); --section
# boundaries are resolved against structural (non-fenced) headings only.
cat > "$extract_awk" <<'AWK'
function trim(s) {
  sub(/^[ \t]+/, "", s)
  sub(/[ \t]+$/, "", s)
  return s
}

function backtick_run(t,    i, c) {
  c = 0
  for (i = 1; i <= length(t); i++) {
    if (substr(t, i, 1) == "`") c++
    else break
  }
  return c
}

function heading_level(t,    i, c) {
  c = 0
  for (i = 1; i <= length(t); i++) {
    if (substr(t, i, 1) == "#") c++
    else break
  }
  return c
}

function is_heading(t,    lvl, rest) {
  lvl = heading_level(t)
  if (lvl < 1 || lvl > 6) return 0
  rest = substr(t, lvl + 1)
  if (rest == "") return 1
  if (substr(rest, 1, 1) == " ") return 1
  return 0
}

function classify_literal(v,    first_word) {
  if (v ~ /\//) {
    if (v !~ /[ \t]/) return "path"
  }
  first_word = v
  sub(/[ \t].*$/, "", first_word)
  if (first_word == "bash" || first_word == "git" || first_word == "gh" || \
      first_word == "acli" || first_word == "pnpm" || first_word == "npm" || \
      first_word == "npx" || first_word == "python3") return "command"
  if (v ~ /^[A-Z][A-Z0-9_]*$/ && length(v) >= 2) return "allcaps"
  return ""
}

function emit(kind, ln, val) {
  print kind ":" ln ":" val
}

function scan_literals(i, line,    rest, inner) {
  rest = line
  while (match(rest, /`[^`]+`/)) {
    inner = trim(substr(rest, RSTART + 1, RLENGTH - 2))
    if (inner != "" && classify_literal(inner) != "") emit("literal", i, inner)
    rest = substr(rest, RSTART + RLENGTH)
  }
}

{ raw[NR] = $0 }

END {
  n = NR

  fm_start = 0
  fm_end = 0
  if (n >= 1 && trim(raw[1]) == "---") {
    fm_start = 1
    for (i = 2; i <= n; i++) {
      if (trim(raw[i]) == "---") { fm_end = i; break }
    }
    if (fm_end == 0) fm_start = 0
  }

  sp = 0
  fence_n = 0
  for (i = 1; i <= n; i++) {
    line_fence_idx[i] = (sp > 0) ? stack_idx[sp] : 0
    line_is_open[i] = 0
    line_is_close[i] = 0

    if (fm_start && i >= fm_start && i <= fm_end) continue

    t = trim(raw[i])
    L = backtick_run(t)
    if (L >= 3) {
      bare = (length(t) == L)
      if (sp > 0) {
        topK = stack_k[sp]
        if (bare && L >= topK) {
          line_is_close[i] = 1
          fence_close_line[stack_idx[sp]] = i
          line_fence_idx[i] = stack_idx[sp]
          sp--
          continue
        }
        if (bare) {
          line_fence_idx[i] = stack_idx[sp]
          continue
        }
      }
      fence_n++
      sp++
      stack_k[sp] = L
      stack_idx[sp] = fence_n
      fence_open_line[fence_n] = i
      fence_info[fence_n] = bare ? "" : trim(substr(t, L + 1))
      fence_close_line[fence_n] = 0
      line_is_open[i] = 1
      line_fence_idx[i] = fence_n
      continue
    }
  }

  if (SECTION != "") {
    target_line = 0
    for (i = 1; i <= n; i++) {
      if (line_fence_idx[i] == 0 && is_heading(trim(raw[i])) && trim(raw[i]) == SECTION) {
        target_line = i
        break
      }
    }
    if (target_line == 0) {
      print "unknown heading: " SECTION > "/dev/stderr"
      exit 2
    }
    target_level = heading_level(trim(raw[target_line]))
    span_start = target_line + 1
    span_end = n
    for (i = target_line + 1; i <= n; i++) {
      if (line_fence_idx[i] == 0 && is_heading(trim(raw[i]))) {
        if (heading_level(trim(raw[i])) <= target_level) { span_end = i - 1; break }
      }
    }
  } else {
    span_start = 1
    span_end = n
  }

  if (FENCESPEC != "") {
    local_count = 0
    for (f = 1; f <= fence_n; f++) {
      if (fence_open_line[f] >= span_start && fence_open_line[f] <= span_end) {
        local_count++
        local_to_global[local_count] = f
      }
    }
    nsel = split(FENCESPEC, req, ",")
    for (s = 1; s <= nsel; s++) {
      idx = req[s] + 0
      if (idx < 1 || idx > local_count) {
        print "fence index out of range: " req[s] " (found " local_count ")" > "/dev/stderr"
        exit 2
      }
      g = local_to_global[idx]
      cstart = fence_open_line[g] + 1
      cend = (fence_close_line[g] > 0) ? fence_close_line[g] - 1 : span_end
      for (i = cstart; i <= cend; i++) scope[i] = 1
    }
  } else {
    for (i = span_start; i <= span_end; i++) scope[i] = 1
  }

  for (i = 1; i <= n; i++) {
    if (!(i in scope)) continue
    if (line_is_open[i]) {
      emit("fence", i, fence_info[line_fence_idx[i]])
      continue
    }
    if (line_is_close[i]) continue

    t = trim(raw[i])
    if (is_heading(t)) {
      emit("heading", i, t)
    } else {
      in_yaml = (line_fence_idx[i] != 0 && fence_info[line_fence_idx[i]] == "yaml")
      in_frontmatter = (fm_start > 0 && i > fm_start && i < fm_end)
      if (in_yaml || in_frontmatter) {
        if (match(t, /^[A-Za-z0-9_.-]+:/)) {
          emit("field", i, substr(t, RSTART, RLENGTH))
        }
      }
    }
    scan_literals(i, raw[i])
  }
}
AWK

cat > "$compare_awk" <<'AWK'
function parse_kind(line,    p) { p = index(line, ":"); return substr(line, 1, p - 1) }
function parse_value(line,    p, rest) {
  p = index(line, ":")
  rest = substr(line, p + 1)
  p = index(rest, ":")
  return substr(rest, p + 1)
}

# esc_char: backslash-escape a single ERE metacharacter; every other character is returned as-is.
function esc_char(c,    meta) {
  meta = ".*+?()[]{}|^$\\"
  if (index(meta, c) > 0) return "\\" c
  return c
}

function is_word_char(c) { return (c ~ /[A-Za-z0-9_]/) }

# regex_of: escape every ERE metacharacter in v, then replace each placeholder run — bracketed
# [...], angled <...>, or the bare ordinal token NNNN or N (word-boundary delimited on both
# sides so `N` inside `NON` or `LEDGER_PHASE` is never a placeholder) — with `.*`, then anchor
# ^...$. Escaping happens character-by-character as we walk left to right, so a literal `[` or
# `1.` in a non-placeholder position is escaped, never treated as a wildcard opener.
function regex_of(v,    result, i, n, closeat, prevc, nextc) {
  result = ""
  n = length(v)
  i = 1
  while (i <= n) {
    if (substr(v, i, 1) == "[") {
      closeat = index(substr(v, i + 1), "]")
      if (closeat > 0) {
        result = result ".*"
        i = i + 1 + closeat
        continue
      }
    }
    if (substr(v, i, 1) == "<") {
      closeat = index(substr(v, i + 1), ">")
      if (closeat > 0) {
        result = result ".*"
        i = i + 1 + closeat
        continue
      }
    }
    if (substr(v, i, 4) == "NNNN") {
      prevc = (i > 1) ? substr(v, i - 1, 1) : ""
      nextc = substr(v, i + 4, 1)
      if (!is_word_char(prevc) && !is_word_char(nextc)) {
        result = result ".*"
        i = i + 4
        continue
      }
    }
    if (substr(v, i, 1) == "N") {
      prevc = (i > 1) ? substr(v, i - 1, 1) : ""
      nextc = substr(v, i + 1, 1)
      if (!is_word_char(prevc) && !is_word_char(nextc)) {
        result = result ".*"
        i = i + 1
        continue
      }
    }
    result = result esc_char(substr(v, i, 1))
    i++
  }
  return "^" result "$"
}

FNR == NR {
  if (NF == 0 && $0 == "") next
  T++
  tkind[T] = parse_kind($0)
  tval[T] = parse_value($0)
  next
}
{
  if (NF == 0 && $0 == "") next
  A++
  akind[A] = parse_kind($0)
  aval[A] = parse_value($0)
}

END {
  # Ordered subsequence, not strict position: a forward-only cursor `a` over the artifact list.
  # For each template item, scan artifact items from `a` upward for the first match; on a match,
  # advance the cursor past it. Artifact-side items the template does not name are skipped, not
  # treated as a mismatch — a produced artifact is legitimately a superset of its template.
  a = 1
  missing = ""
  matched = 0
  for (j = 1; j <= T; j++) {
    tre = regex_of(tval[j])
    found = 0
    for (i = a; i <= A; i++) {
      if (tkind[j] == akind[i] && aval[i] ~ tre) {
        found = 1
        matched++
        a = i + 1
        break
      }
    }
    if (!found) {
      item = tkind[j] ":" tval[j]
      missing = (missing == "") ? item : missing ";;" item
    }
  }
  print "TEMPLATE=" TEMPLATE_PATH
  print "ARTIFACT=" ARTIFACT_PATH
  print "CONTRACT_TEMPLATE=" T
  print "CONTRACT_ARTIFACT=" matched
  print "CONTRACT_MISSING=" missing
  print "CONTRACT_MATCH=" (missing == "" ? "true" : "false")
  exit (missing == "" ? 0 : 1)
}
AWK

if [ "$mode" = "extract" ]; then
  abs_path="$repo_root/$extract_path"
  if [ ! -f "$abs_path" ] || [ ! -r "$abs_path" ]; then
    echo "artifact-contract: cannot read: $extract_path" >&2
    exit 2
  fi
  awk -v SECTION="$section" -v FENCESPEC="$fence_spec" -f "$extract_awk" "$abs_path"
  status=$?
  exit "$status"
fi

# diff mode: --template [--section] [--fence] --artifact
tpl_abs="$repo_root/$template_path"
if [ ! -f "$tpl_abs" ] || [ ! -r "$tpl_abs" ]; then
  echo "TEMPLATE=$template_path"
  echo "ARTIFACT=$artifact_path"
  echo "CONTRACT_ARTIFACT=-1"
  echo "REASON=template unreadable: $template_path"
  exit 2
fi

tpl_items="$(mktemp)"
tpl_err="$(mktemp)"
awk -v SECTION="$section" -v FENCESPEC="$fence_spec" -f "$extract_awk" "$tpl_abs" > "$tpl_items" 2> "$tpl_err"
tpl_status=$?
if [ "$tpl_status" -ne 0 ]; then
  reason="$(head -n1 "$tpl_err")"
  echo "TEMPLATE=$template_path"
  echo "ARTIFACT=$artifact_path"
  echo "CONTRACT_ARTIFACT=-1"
  echo "REASON=$reason"
  exit 2
fi

art_abs="$repo_root/$artifact_path"
if [ ! -f "$art_abs" ] || [ ! -r "$art_abs" ]; then
  echo "TEMPLATE=$template_path"
  echo "ARTIFACT=$artifact_path"
  echo "CONTRACT_ARTIFACT=-1"
  echo "REASON=artifact unreadable: $artifact_path"
  exit 2
fi

art_items="$(mktemp)"
art_err="$(mktemp)"
awk -v SECTION="" -v FENCESPEC="" -f "$extract_awk" "$art_abs" > "$art_items" 2> "$art_err"
art_status=$?
if [ "$art_status" -ne 0 ]; then
  reason="$(head -n1 "$art_err")"
  echo "TEMPLATE=$template_path"
  echo "ARTIFACT=$artifact_path"
  echo "CONTRACT_ARTIFACT=-1"
  echo "REASON=$reason"
  exit 2
fi

awk -v TEMPLATE_PATH="$template_path" -v ARTIFACT_PATH="$artifact_path" \
  -f "$compare_awk" "$tpl_items" "$art_items"
exit $?
