#!/usr/bin/env bash
# artifact-encoding.test.sh — NA-87 CI guard for the five self-generated-artifact templates
# (spec, plan, ADR, QA review-round file, memory rule entry). Asserts each template carries the
# artifact-encoding pointer line exactly once, that no in-fence table row across the five is
# padded (the regression guard for the writing-specs template-fence repair), and that
# refs/artifact-encoding.md itself stays pointer-only (never auto-loaded), mirroring the
# pseudocode-notation.md contract.
#
# Self-runnable, no test harness/framework dependency:
#   bash plugins/sdlc/scripts/__tests__/artifact-encoding.test.sh
# Exit 0 = PASS (all assertions), exit 1 = FAIL (any assertion).
set -uo pipefail

here="${BASH_SOURCE[0]%/*}"; [ "$here" = "${BASH_SOURCE[0]}" ] && here="."
here="$(cd "$here" && pwd)"
# plugins/sdlc/scripts/__tests__ -> repo root is four levels up.
repo_root="$(cd "$here/../../../.." && pwd)"
cd "$repo_root" || {
  echo "artifact-encoding.test.sh: FAILED — cannot cd to repo root ($here/../../../..)" >&2
  exit 1
}

failures=0

surfaces=(
  "plugins/sdlc/skills/writing-specs/SKILL.md"
  "plugins/sdlc/agents/tech-lead.md"
  "plugins/sdlc/skills/writing-adrs/SKILL.md"
  "plugins/sdlc/refs/qa-engineer-playbook.md"
  "plugins/sdlc/refs/domain-agent-handoff.md"
)

marker="refs/artifact-encoding.md"

# --- Assertion 1: pointer line present, exactly once per surface ---------------------------
for f in "${surfaces[@]}"; do
  if [ ! -f "$f" ]; then
    echo "FAIL: assertion 1 — surface not found: $f" >&2
    failures=$((failures + 1))
    continue
  fi
  count="$(grep -Fc -- "$marker" "$f")"
  if [ "$count" -eq 1 ]; then
    echo "PASS: assertion 1 — $f carries the artifact-encoding pointer line exactly once"
  else
    echo "FAIL: assertion 1 — $f carries the pointer line $count time(s), expected exactly 1" >&2
    failures=$((failures + 1))
  fi
done

# --- Assertion 2: no padded table row inside any fence, across the five surfaces -----------
# In-fence complement of instruction-inventory.sh --padding (which excludes fenced content by
# design): a fenced table row is padded when a run of 2+ spaces sits between a `|` and cell
# content, or when a delimiter-row cell's dash run is longer than the unpadded `---` form.
check_fence_padding() {
  awk -v FILE="$1" '
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    BEGIN { fence = 0; fails = 0 }
    {
      t = trim($0)
      if (t ~ /^```/) { fence = !fence; next }
      if (!fence) next
      if (t !~ /^\|.*\|$/) next
      inner = substr(t, 2, length(t) - 2)
      n = split(inner, cells, "|")
      isdelim = 1
      for (i = 1; i <= n; i++) {
        c = trim(cells[i])
        if (c !~ /^:?-+:?$/) isdelim = 0
      }
      if (isdelim) {
        for (i = 1; i <= n; i++) {
          c = trim(cells[i])
          gsub(/:/, "", c)
          if (length(c) > 3) {
            print "FAIL: assertion 2 — padded delimiter row in fence: " FILE ":" NR > "/dev/stderr"
            fails++
          }
        }
      } else {
        if (t ~ /\|[ \t][ \t]+[^ \t|]/ || t ~ /[^ \t|][ \t][ \t]+\|/) {
          print "FAIL: assertion 2 — padded table row in fence: " FILE ":" NR > "/dev/stderr"
          fails++
        }
      }
    }
    END { exit (fails > 0 ? 1 : 0) }
  ' "$1"
}

any_padding=0
for f in "${surfaces[@]}"; do
  [ -f "$f" ] || continue
  if check_fence_padding "$f"; then
    :
  else
    any_padding=1
    failures=$((failures + 1))
  fi
done
if [ "$any_padding" -eq 0 ]; then
  echo "PASS: assertion 2 — no padded table row inside any fence across the five surfaces"
fi

# --- Assertion 3: refs/artifact-encoding.md exists and stays pointer-only ------------------
ref_file="plugins/sdlc/refs/artifact-encoding.md"
if [ ! -f "$ref_file" ]; then
  echo "FAIL: assertion 3 — $ref_file does not exist" >&2
  failures=$((failures + 1))
else
  echo "PASS: assertion 3 — $ref_file exists"
fi

is_known_surface() {
  local candidate="$1" s
  for s in "${surfaces[@]}"; do
    [ "$candidate" = "$s" ] && return 0
  done
  return 1
}

# 3a. every agents/*.md frontmatter must not name artifact-encoding
for f in plugins/sdlc/agents/*.md; do
  [ -f "$f" ] || continue
  fm="$(awk 'NR==1 && $0=="---" { p=1; next } p==1 && $0=="---" { exit } p==1 { print }' "$f")"
  if printf '%s' "$fm" | grep -q "artifact-encoding"; then
    echo "FAIL: assertion 3 — $f frontmatter names artifact-encoding.md (must stay pointer-only)" >&2
    failures=$((failures + 1))
  fi
done

# 3b. every "Required skills"-headed section anywhere under plugins/sdlc/ must not name it
while IFS= read -r f; do
  [ -n "$f" ] || continue
  case "$f" in plugins/sdlc/skills/find-skills/*|plugins/sdlc/skills/skill-creator/*) continue ;; esac
  hit="$(awk '
    BEGIN { insect = 0 }
    /^#+[ \t]/ {
      insect = ($0 ~ /[Rr]equired [Ss]kills/) ? 1 : 0
      next
    }
    insect && /artifact-encoding/ { print FILENAME ":" NR; exit }
  ' "$f")"
  if [ -n "$hit" ]; then
    echo "FAIL: assertion 3 — Required-skills section names artifact-encoding.md: $hit" >&2
    failures=$((failures + 1))
  fi
done < <(find plugins/sdlc -name "*.md" -type f)

# 3c. catch-all — no reference to artifact-encoding.md anywhere under plugins/sdlc/ outside the
# ref file itself and the five known template pointer lines (catches any other auto-loaded list).
while IFS= read -r f; do
  [ -n "$f" ] || continue
  [ "$f" = "$ref_file" ] && continue
  if ! is_known_surface "$f"; then
    echo "FAIL: assertion 3 — unexpected artifact-encoding.md reference outside the five templates: $f" >&2
    failures=$((failures + 1))
  fi
done < <(grep -rl "artifact-encoding" plugins/sdlc --include="*.md" 2>/dev/null)

if [ "$failures" -ne 0 ]; then
  echo
  echo "artifact-encoding.test.sh: FAILED ($failures assertion(s) failed)"
  exit 1
fi

echo
echo "artifact-encoding.test.sh: PASS — all assertions passed"
exit 0
