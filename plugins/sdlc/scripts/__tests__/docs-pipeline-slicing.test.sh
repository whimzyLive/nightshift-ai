#!/usr/bin/env bash
# docs-pipeline-slicing.test.sh — regression test pinning the docs-pipeline.md monolith split
# (NA-79).
#
# Self-runnable, no test harness/framework dependency:
#   bash plugins/sdlc/scripts/__tests__/docs-pipeline-slicing.test.sh
# Exit 0 = PASS (all cases), non-zero = FAIL (any case).
set -uo pipefail

here="${BASH_SOURCE[0]%/*}"; [ "$here" = "${BASH_SOURCE[0]}" ] && here="."
plugin_root="$(cd "$here/../.." && pwd)"
refs_dir="$plugin_root/refs"
agents_dir="$plugin_root/agents"
commands_dir="$plugin_root/commands"
skills_dir="$plugin_root/skills"
scripts_dir="$plugin_root/scripts"
playbook="$refs_dir/principal-engineer-playbook.md"
knowledge_engineer="$agents_dir/knowledge-engineer.md"
monolith="$refs_dir/docs-pipeline.md"
# This test's own path — it necessarily contains the literal string "docs-pipeline.md" as part of
# testing for it (comments, the $monolith assignment, echoed messages). Excluded from Case 5's
# dangling-reference scan alongside $monolith itself, for the same reason: neither is a live
# pointer INTO the removed monolith, they are what tests for one.
self_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

if [ ! -d "$refs_dir" ] || [ ! -d "$agents_dir" ]; then
  echo "FAIL: setup — refs_dir=$refs_dir or agents_dir=$agents_dir not found"
  echo "FAIL: 1 docs-pipeline-slicing regression case(s) failed"
  exit 1
fi

failures=0

core="$refs_dir/docs-pipeline-core.md"
release="$refs_dir/docs-pipeline-release.md"
seed="$refs_dir/docs-pipeline-seed.md"
audit="$refs_dir/docs-pipeline-audit.md"
postqa="$refs_dir/docs-pipeline-postqa.md"

# Case 1
missing=""
for f in "$core" "$release" "$seed" "$audit" "$postqa"; do
  [ -s "$f" ] || missing="$missing $f"
done
if [ -z "$missing" ]; then
  echo "PASS: mode slices — docs-pipeline-{core,release,seed,audit,postqa}.md all exist and are non-empty"
else
  echo "FAIL: mode slices — missing or empty:$missing"
  failures=$((failures + 1))
fi

# Case 2
CEILING_BYTES=70321
if [ -f "$core" ] && [ -f "$postqa" ]; then
  combined=$(( $(wc -c < "$core") + $(wc -c < "$postqa") ))
else
  combined=999999999
fi
if [ "$combined" -le "$CEILING_BYTES" ]; then
  echo "PASS: post-QA required reading — core+postqa combined ${combined} bytes <= ${CEILING_BYTES}-byte ceiling (40% of the 175,803-byte docs-pipeline.md monolith measured at NA-79 root-cause)"
else
  echo "FAIL: post-QA required reading — core+postqa combined ${combined} bytes exceeds the ${CEILING_BYTES}-byte ceiling (40% of the 175,803-byte docs-pipeline.md monolith measured at NA-79 root-cause)"
  failures=$((failures + 1))
fi

# Case 3
MONOLITH_MAX_BYTES=4096
monolith_bytes=""
[ -f "$monolith" ] && monolith_bytes="$(wc -c < "$monolith" | tr -d ' ')"
if [ ! -e "$monolith" ]; then
  echo "PASS: monolith removed — $monolith no longer exists"
elif [ -n "$monolith_bytes" ] && [ "$monolith_bytes" -le "$MONOLITH_MAX_BYTES" ]; then
  echo "PASS: monolith replaced — $monolith is ${monolith_bytes} bytes <= ${MONOLITH_MAX_BYTES}-byte thin-pointer ceiling, smaller than the smallest 7413-byte postqa slice measured at NA-79 root-cause so real content can never pass as 'thin'"
else
  size="${monolith_bytes:-?}"
  echo "FAIL: monolith remains — $monolith is ${size} bytes, exceeds the ${MONOLITH_MAX_BYTES}-byte thin-pointer ceiling (was the 175,803-byte NA-79 monolith)"
  failures=$((failures + 1))
fi

# Case 4
if [ -f "$knowledge_engineer" ]; then
  sync_bullet="$(awk '
    f && /^- \*\*release dispatch\*\*/ { exit }
    /^- \*\*docs-sync dispatch\*\*/ { f = 1 }
    f { print }
  ' "$knowledge_engineer")"
  postqa_bullet="$(awk '
    f && /^### / { exit }
    /Post-QA inline variant/ { f = 1 }
    f { print }
  ' "$knowledge_engineer")"
else
  sync_bullet=""
  postqa_bullet=""
fi
if printf '%s' "$sync_bullet" | grep -qF "docs-pipeline-core.md"; then
  echo "PASS: docs-sync pointer — knowledge-engineer.md's docs-sync dispatch bullet names docs-pipeline-core.md"
else
  echo "FAIL: docs-sync pointer — knowledge-engineer.md's docs-sync dispatch bullet does not name docs-pipeline-core.md"
  failures=$((failures + 1))
fi
if printf '%s' "$postqa_bullet" | grep -qF "docs-pipeline-postqa.md"; then
  echo "PASS: docs-sync pointer — knowledge-engineer.md's post-QA inline variant bullet names docs-pipeline-postqa.md"
else
  echo "FAIL: docs-sync pointer — knowledge-engineer.md's post-QA inline variant bullet does not name docs-pipeline-postqa.md"
  failures=$((failures + 1))
fi

# Case 5
dangling="$(grep -rlF "docs-pipeline.md" "$agents_dir" "$commands_dir" "$refs_dir" "$skills_dir" "$scripts_dir" 2>/dev/null | grep -vF "$monolith" | grep -vF "$self_path" || true)"
if [ -z "$dangling" ]; then
  echo "PASS: no dangling references — no live plugin source file under agents/commands/refs/skills/scripts still points at the removed docs-pipeline.md monolith"
else
  echo "FAIL: dangling references — file(s) still pointing at docs-pipeline.md:"
  printf '%s\n' "$dangling" | sed 's/^/    /'
  failures=$((failures + 1))
fi

# Case 6
if [ -f "$playbook" ]; then
  step65="$(awk '
    f && /^## Step 7/ { exit }
    /^## Step 6\.5/ { f = 1 }
    f { print }
  ' "$playbook")"
else
  step65=""
fi
manifest_absent_re='docs-manifest\.md[^.]*absent'
change_size_re='change-size gate|no manifest-tracked (files|surface|path|paths)|touches no manifest-tracked'
if printf '%s' "$step65" | grep -qiE -- "$manifest_absent_re" \
   && printf '%s' "$step65" | grep -qiE -- "$change_size_re"; then
  echo "PASS: Step 6.5 change-size gate — playbook documents a diff-touches-no-manifest-tracked-surface no-op alongside the existing manifest-absent no-op"
else
  echo "FAIL: Step 6.5 change-size gate — playbook is missing the diff-touches-no-manifest-tracked-surface no-op (only the manifest-absent no-op exists)"
  failures=$((failures + 1))
fi

# Case 7 — generic slice-consistency: no docs-pipeline-*.md may carry a bare "§N" whose section
# lives in a DIFFERENT slice without a docs-pipeline-*.md filename qualifying it somewhere in the
# same paragraph. This is the semantic successor to Case 5's literal-string check (which only
# catches a reference to the removed monolith's own filename, not a live but unqualified
# cross-slice section pointer within the surviving slices themselves).
case7_output="$(PLUGIN_ROOT="$plugin_root" python3 - <<'PYEOF'
import os
import re
import sys

plugin_root = os.environ["PLUGIN_ROOT"]
refs_dir = os.path.join(plugin_root, "refs")

# Section -> owning slice, per NA-79's fixed §-boundary table (do not renumber).
RANGES = {
    "core": range(1, 10),
    "release": range(10, 15),
    "seed": range(15, 20),
    "audit": range(20, 25),
    "postqa": range(25, 27),
}
owner = {n: slice_name for slice_name, rng in RANGES.items() for n in rng}

sec_re = re.compile(r"\xa7+(\d+)")  # one or two section-sign (§) chars, then digits
# A backtick-quoted "*.md" filename mention — used to detect a "§N" that actually belongs to a
# DIFFERENT document's own numbering (e.g. "`refs/adr-pipeline.md` §3a") rather than to the
# docs-pipeline slice registry at all. Window is tight (looks only at text immediately before the
# "§N", not the whole paragraph) so an unrelated earlier filename mention can't mask a real
# docs-pipeline cross-slice violation later in the same paragraph.
FILENAME_WINDOW = 120
filename_re = re.compile(r"`([\w./-]+\.md)`")
violations = []

for slice_name in RANGES:
    path = os.path.join(refs_dir, f"docs-pipeline-{slice_name}.md")
    if not os.path.isfile(path):
        continue
    with open(path, encoding="utf-8") as f:
        text = f.read()

    # Split into paragraphs (blocks separated by a blank line), tracking each paragraph's
    # start offset so a violation can be reported with a real line number.
    paragraphs = []
    start = 0
    for sep in re.finditer(r"\n\s*\n", text):
        paragraphs.append((start, text[start:sep.start()]))
        start = sep.end()
    paragraphs.append((start, text[start:]))

    for para_start, para in paragraphs:
        for m in sec_re.finditer(para):
            n = int(m.group(1))
            target_slice = owner.get(n)
            if target_slice is None or target_slice == slice_name:
                continue  # unknown section number, or a same-slice self-reference — fine either way

            # Does the nearest preceding filename mention (within a tight window) belong to some
            # OTHER document entirely (e.g. refs/adr-pipeline.md)? If so this "§N" is that
            # document's own numbering, not a docs-pipeline cross-slice pointer — not our concern.
            window_start = max(0, m.start() - FILENAME_WINDOW)
            preceding = para[window_start:m.start()]
            nearest_fname = None
            for fm in filename_re.finditer(preceding):
                nearest_fname = fm.group(1)  # last match wins — the CLOSEST preceding filename
            if nearest_fname is not None and not nearest_fname.startswith("docs-pipeline-"):
                continue  # scoped to a different file's own section numbering

            qualifier = f"docs-pipeline-{target_slice}.md"
            if qualifier in para:
                continue  # qualified somewhere in the same paragraph
            line_no = text.count("\n", 0, para_start + m.start()) + 1
            violations.append(
                (f"docs-pipeline-{slice_name}.md", line_no, n, target_slice)
            )

if violations:
    for fname, line_no, n, target_slice in violations:
        print(
            f"FAIL: slice-consistency — {fname}:{line_no}: bare §{n} "
            f"(lives in docs-pipeline-{target_slice}.md) with no docs-pipeline-{target_slice}.md "
            f"qualifier nearby"
        )
    sys.exit(1)

print(
    "PASS: slice-consistency — no docs-pipeline-*.md carries an unqualified cross-slice "
    "§N reference"
)
sys.exit(0)
PYEOF
)"
case7_exit=$?
printf '%s\n' "$case7_output"
if [ "$case7_exit" -ne 0 ]; then
  failures=$((failures + 1))
fi

if [ "$failures" -eq 0 ]; then
  echo "PASS: all docs-pipeline-slicing regression cases passed"
  exit 0
else
  echo "FAIL: $failures docs-pipeline-slicing regression case(s) failed"
  exit 1
fi
