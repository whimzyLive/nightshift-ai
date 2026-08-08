#!/usr/bin/env bash
set -uo pipefail
shopt -s nullglob

here="$(cd "$(dirname "$0")" && pwd)"
vocab_file="$here/../refs/root-cause-vocab.txt"
# shellcheck source=/dev/null
. "$here/memory-root.sh"

explicit_root="${1:-}"
repo_root="$explicit_root"
if [ -z "$repo_root" ]; then
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"
  [ -z "$repo_root" ] && repo_root="$(pwd)"
fi

# mem_roots — newline-delimited TSV pairs "<tracked-root><TAB><captured-root>". arg1 present ->
# LEGACY-ONLY (fixture runs stay hermetic and byte-identical; both columns equal explicit_root).
# arg1 absent -> DUAL: resolved root (both columns equal — capture-learning.sh writes captures
# there directly), then the legacy entry, where the two columns DIVERGE: the tracked corpus
# (agents/**, reviews/**) is checked out identically in every worktree, so <git-toplevel> is
# correct for column 1 — but captured/** is untracked and gitignored, so it exists ONLY in the
# PRIMARY checkout. From a linked worktree, <git-toplevel>/captured is empty even when the primary
# has staged captures list-captured.sh can see, so column 2 resolves via sdlc_primary_worktree
# (matching list-captured.sh), falling back to column 1 if that fails.
# The legacy entry is the NA-101 transition shim. NA-102 ships migrate-memory-root.sh (the
# one-shot corpus move) but deliberately does NOT remove this shim — it stays a harmless no-op
# once the tree is empty; removing it is explicitly out of NA-102's scope and left to a
# follow-up story.
mem_roots=""
resolver_failed=0
if [ -n "$explicit_root" ]; then
  [ -d "$explicit_root/.claude/memories" ] \
    && mem_roots="$explicit_root/.claude/memories	$explicit_root/.claude/memories"
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
    resolver_failed=1
    echo "check-frontmatter: RESOLVER-FAILED — ${resolver_err:-memory-root.sh could not resolve a root}" >&2
  elif [ -d "$resolved" ]; then
    mem_roots="$resolved	$resolved"
  fi
  if [ -d "$repo_root/.claude/memories" ]; then
    legacy_captured_root="$repo_root"
    legacy_primary="$(sdlc_primary_worktree 2>/dev/null)" || legacy_primary=""
    [ -n "$legacy_primary" ] && legacy_captured_root="$legacy_primary"
    mem_roots="$mem_roots${mem_roots:+
}$repo_root/.claude/memories	$legacy_captured_root/.claude/memories"
  fi
fi

vocab_list=""
if [ -f "$vocab_file" ]; then
  vocab_list="$(grep -v '^[[:space:]]*#' "$vocab_file" | grep -v '^[[:space:]]*$')"
fi
vocab_display="$(printf '%s' "$vocab_list" | paste -sd, - | sed 's/,/, /g')"

vocab_contains() {
  printf '%s\n' "$vocab_list" | grep -qxF -- "$1"
}

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

list_len() {
  if [ -z "$1" ]; then
    echo 0
  else
    printf '%s' "$1" | awk -F',' '{print NF}'
  fi
}

valid_evidence_item() {
  # [A-Z0-9]* (not +) — a single-letter Jira project key (e.g. "A-1") is a valid story key per
  # validate_story_key in capture-learning.sh; the two regexes must agree (NA-103 Minor 6).
  [[ "$1" =~ ^[A-Z][A-Z0-9]*-[0-9]+$ ]] && return 0
  [[ "$1" =~ ^PR#[0-9]+$ ]] && return 0
  [[ "$1" =~ ^[0-9a-f]{7,40}$ ]] && return 0
  return 1
}

offenders=""
warnings=""
id_records=""

add_offender() { offenders+="$1"$'\n'; }
add_warning() { warnings+="$1"$'\n'; }

# A SKIP here is informational, never a script-level exit — corpus_skipped only means the
# rule/review/capture while-loop below has nothing to iterate (it already no-ops safely on an
# empty $mem_roots, via its own `[ -n "$mem_root" ] || continue`). The ADR frontmatter loop further
# down is unconditional and independent of the memory-root corpus entirely: exiting early here used
# to skip it too, silently disabling the only ADR frontmatter guard in the repo whenever the memory
# root was absent (e.g. every fresh CI checkout once AC5 removed the last tracked file under
# `.claude/memories/`) — see NA-103.
if [ -z "$mem_roots" ] && [ "$resolver_failed" -eq 0 ]; then
  echo "check-frontmatter: SKIP: no memory root — nothing to validate (0 files); ADR frontmatter is still checked below"
fi

validate_rule_file() {
  local file="$1" dirname="$2"
  local base stem fm parsed
  base="$(basename "$file")"
  stem="${base%.md}"

  fm="$(extract_fm "$file")"
  if [ -z "$fm" ]; then
    add_offender "$file: missing or unparseable frontmatter"
    return
  fi
  parsed="$(printf '%s\n' "$fm" | parse_frontmatter)"

  local issues=""
  local field
  for field in id agent trigger rule evidence uses status; do
    has_field "$parsed" "$field" || issues+="missing field '$field'; "
  done

  local id agent_list trig rule_val evidence_val uses_val status_val
  id="$(field_value "$parsed" id)"
  agent_list="$(field_value "$parsed" agent)"
  trig="$(field_value "$parsed" trigger)"
  rule_val="$(field_value "$parsed" rule)"
  evidence_val="$(field_value "$parsed" evidence)"
  uses_val="$(field_value "$parsed" uses)"
  status_val="$(field_value "$parsed" status)"

  if [ -z "$id" ]; then
    issues+="id is empty; "
  else
    id_records+="$id|$file"$'\n'
    [ "$id" != "$stem" ] && issues+="id '$id' does not equal filename stem '$stem'; "
  fi

  if [ -z "$agent_list" ]; then
    issues+="agent list is empty; "
  elif [ "$dirname" = "shared" ]; then
    local shared_len
    shared_len="$(list_len "$agent_list")"
    [ "$shared_len" -lt 2 ] && issues+="agents/shared/ rule must have agent length >= 2, got [$agent_list]; "
  else
    if [ "$agent_list" != "$dirname" ]; then
      issues+="under agents/$dirname/ agent must be exactly [$dirname], got [$agent_list]; "
    fi
  fi

  local trig_len
  trig_len="$(list_len "$trig")"
  if [ "$trig_len" -lt 1 ] || [ "$trig_len" -gt 6 ]; then
    issues+="trigger must have 1-6 items, got $trig_len; "
  fi

  if [ -z "$rule_val" ]; then
    issues+="rule is empty; "
  elif [ "${#rule_val}" -gt 200 ]; then
    issues+="rule exceeds 200 chars (${#rule_val}); "
  fi

  local evidence_len
  evidence_len="$(list_len "$evidence_val")"
  if [ "$evidence_len" -lt 1 ]; then
    issues+="evidence is empty; "
  else
    local IFS_OLD="$IFS" item
    IFS=','
    for item in $evidence_val; do
      valid_evidence_item "$item" || issues+="evidence item '$item' is not a Jira key, PR#n, or 7-40 char SHA; "
    done
    IFS="$IFS_OLD"
  fi

  if ! [[ "$uses_val" =~ ^[0-9]+$ ]]; then
    issues+="uses '$uses_val' is not a non-negative integer; "
  fi

  case "$status_val" in
    active | deprecated | promoted) ;;
    *) issues+="status '$status_val' is not one of active|deprecated|promoted; " ;;
  esac

  [ -n "$issues" ] && add_offender "$file: $issues"
}

validate_review_file() {
  local file="$1"
  local base stem fm parsed
  base="$(basename "$file")"
  stem="${base%.md}"

  if ! [[ "$stem" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2})-([A-Z][A-Z0-9]*-[0-9]+)(-r[0-9]+)?$ ]]; then
    add_offender "$file: filename does not match YYYY-MM-DD-<KEY>[-rN].md"
    return
  fi
  local fname_date="${BASH_REMATCH[1]}" fname_key="${BASH_REMATCH[2]}"

  fm="$(extract_fm "$file")"
  if [ -z "$fm" ]; then
    add_offender "$file: missing or unparseable frontmatter"
    return
  fi
  parsed="$(printf '%s\n' "$fm" | parse_frontmatter)"

  local issues=""
  local field
  for field in story date domains root_causes issue_count; do
    has_field "$parsed" "$field" || issues+="missing field '$field'; "
  done

  local story_val date_val domains_val root_causes_val issue_count_val
  story_val="$(field_value "$parsed" story)"
  date_val="$(field_value "$parsed" date)"
  domains_val="$(field_value "$parsed" domains)"
  root_causes_val="$(field_value "$parsed" root_causes)"
  issue_count_val="$(field_value "$parsed" issue_count)"

  [ "$story_val" != "$fname_key" ] && issues+="story '$story_val' disagrees with filename key '$fname_key'; "
  [ "$date_val" != "$fname_date" ] && issues+="date '$date_val' disagrees with filename date '$fname_date'; "

  if ! [[ "$issue_count_val" =~ ^[0-9]+$ ]]; then
    issues+="issue_count '$issue_count_val' is not a non-negative integer; "
  fi

  local domains_len root_causes_len
  domains_len="$(list_len "$domains_val")"
  root_causes_len="$(list_len "$root_causes_val")"

  if [ "$domains_len" -eq 0 ] && [ "$issue_count_val" != "0" ]; then
    issues+="domains is empty but issue_count is not 0; "
  fi
  if [ "$root_causes_len" -eq 0 ] && [ "$issue_count_val" != "0" ]; then
    issues+="root_causes is empty but issue_count is not 0; "
  fi

  if [ -n "$root_causes_val" ]; then
    local IFS_OLD="$IFS" token
    IFS=','
    for token in $root_causes_val; do
      vocab_contains "$token" || issues+="root_causes token '$token' is not in the vocabulary; accepted: $vocab_display; "
    done
    IFS="$IFS_OLD"
  fi

  [ -n "$issues" ] && add_offender "$file: $issues"
}

validate_capture_file() {
  local file="$1" kind="$2"
  local base stem fm parsed issues field
  base="$(basename "$file")"
  stem="${base%.md}"

  fm="$(extract_fm "$file")"
  if [ -z "$fm" ]; then
    add_warning "$file: missing or unparseable frontmatter"
    return
  fi
  parsed="$(printf '%s\n' "$fm" | parse_frontmatter)"

  issues=""
  if [ "$kind" = "rule" ]; then
    for field in id agent trigger rule evidence uses status captured story origin promote-target; do
      has_field "$parsed" "$field" || issues+="missing field '$field'; "
      [ -z "$(field_value "$parsed" "$field")" ] && issues+="empty field '$field'; "
    done
    local status_val id_val origin_val
    status_val="$(field_value "$parsed" status)"
    [ "$status_val" != "captured" ] && issues+="status '$status_val' is not 'captured'; "
    id_val="$(field_value "$parsed" id)"
    [ "${stem#*--}" != "$id_val" ] && issues+="id '$id_val' does not match filename segment '${stem#*--}'; "
    origin_val="$(field_value "$parsed" origin)"
    case "$origin_val" in
      domain-agent | qa-round) ;;
      *) issues+="origin '$origin_val' is not one of domain-agent|qa-round; " ;;
    esac
  else
    for field in story date domains root_causes issue_count captured origin promote-target; do
      has_field "$parsed" "$field" || issues+="missing field '$field'; "
    done
    local issue_count_val
    issue_count_val="$(field_value "$parsed" issue_count)"
    for field in story date issue_count captured origin promote-target; do
      [ -z "$(field_value "$parsed" "$field")" ] && issues+="empty field '$field'; "
    done
    if [ "$issue_count_val" != "0" ]; then
      [ -z "$(field_value "$parsed" domains)" ] && issues+="empty field 'domains'; "
      [ -z "$(field_value "$parsed" root_causes)" ] && issues+="empty field 'root_causes'; "
    fi
    local origin_val story_val date_val
    origin_val="$(field_value "$parsed" origin)"
    [ "$origin_val" != "qa-round" ] && issues+="origin '$origin_val' is not 'qa-round'; "
    story_val="$(field_value "$parsed" story)"
    date_val="$(field_value "$parsed" date)"
    if [[ "$stem" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2})-([A-Z][A-Z0-9]*-[0-9]+)(-r[0-9]+)?$ ]]; then
      [ "$story_val" != "${BASH_REMATCH[2]}" ] && issues+="story '$story_val' disagrees with filename key '${BASH_REMATCH[2]}'; "
      [ "$date_val" != "${BASH_REMATCH[1]}" ] && issues+="date '$date_val' disagrees with filename date '${BASH_REMATCH[1]}'; "
    else
      issues+="filename does not match YYYY-MM-DD-<KEY>[-rN].md; "
    fi
  fi

  local pt
  pt="$(field_value "$parsed" promote-target)"
  case "$pt" in
    agents/*|reviews/*) : ;;
    "") : ;;   # an empty promote-target is already reported by the per-kind field loop above
    *) issues+="promote-target '$pt' is not root-relative — expected agents/... or reviews/...; " ;;
  esac

  [ -n "$issues" ] && add_warning "$file: $issues"
}

while IFS=$'\t' read -r mem_root captured_root; do
  [ -n "$mem_root" ] || continue
  [ -n "$captured_root" ] || captured_root="$mem_root"
  id_records=""          # duplicate-id detection is PER ROOT: the same id in both roots is
  validated=0            # expected mid-migration, never a defect

  for f in "$mem_root"/agents/*.md; do
    add_warning "$f is a v1 flat diary; migrate to <memory-root>/agents/<agent>/<rule-id>.md (NA-74)"
  done

  for dir in "$mem_root"/agents/*/; do
    agentdir="$(basename "$dir")"
    for f in "$dir"*.md; do
      validate_rule_file "$f" "$agentdir"; validated=$((validated + 1))
    done
  done

  if [ -n "$id_records" ]; then
    dupe_ids="$(printf '%s' "$id_records" | cut -d'|' -f1 | sort | uniq -d)"
    if [ -n "$dupe_ids" ]; then
      while IFS= read -r dup; do
        [ -z "$dup" ] && continue
        files_for_dup="$(printf '%s' "$id_records" | awk -F'|' -v id="$dup" '$1==id {print $2}' | paste -sd, -)"
        add_offender "duplicate id '$dup' across: $files_for_dup"
      done <<< "$dupe_ids"
    fi
  fi

  for f in "$mem_root"/reviews/*.md; do
    base="$(basename "$f")"
    if [ "$base" = "patterns.md" ]; then
      add_warning "$f is the legacy patterns.md audit log; migrate to per-round review files (NA-74)"
      continue
    fi
    validate_review_file "$f"; validated=$((validated + 1))
  done

  # captured/** is scanned via $captured_root, not $mem_root — they diverge for the legacy entry
  # from a linked worktree (see the mem_roots comment above).
  for f in "$captured_root"/captured/rules/*.md;   do [ -e "$f" ] && { validate_capture_file "$f" rule;   validated=$((validated + 1)); }; done
  for f in "$captured_root"/captured/reviews/*.md; do [ -e "$f" ] && { validate_capture_file "$f" review; validated=$((validated + 1)); }; done

  echo "check-frontmatter: $validated file(s) validated under $mem_root"
done <<< "$mem_roots"

# ADR frontmatter must open on line 1 — every frontmatter reader in this repo uses the
# `NR==1 && $0=="---"` idiom (see extract_fm above), so a stray line (e.g. the writing-adrs
# template's artifact-encoding pointer, accidentally left inside the fence) before the opening
# `---` makes the frontmatter invisible to every reader, including collect-memory.sh — exactly
# how docs/adr/0019-0021 shipped with zero agents reachable despite a populated `agents:` field.
validate_adr_frontmatter() {
  local file="$1" first_line
  first_line="$(head -n 1 "$file")"
  [ "$first_line" = "---" ] || add_offender "$file: line 1 is not '---' — frontmatter is invisible to every NR==1-anchored reader in this repo"
}

for f in "$repo_root"/docs/adr/*.md; do
  [ "$(basename "$f")" = "index.md" ] && continue   # generated index, carries no frontmatter
  validate_adr_frontmatter "$f"
done

if [ -n "$warnings" ]; then
  echo "check-frontmatter: WARNING — legacy memory artifacts present (migration is NA-74):" >&2
  printf '%s' "$warnings" | sed 's/^/  - /' >&2
fi

if [ -n "$offenders" ]; then
  echo "check-frontmatter: FAILED"
  echo
  printf '%s' "$offenders" | sed 's/^/  - /'
  exit 1
fi

if [ "$resolver_failed" -eq 1 ]; then
  echo "check-frontmatter: FAILED — resolver failure (see stderr); the legacy root was validated but the gate cannot be green"
  exit 1
fi

echo "check-frontmatter: OK"
exit 0
