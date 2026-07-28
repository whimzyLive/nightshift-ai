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
playbook="$refs_dir/principal-engineer-playbook.md"
knowledge_engineer="$agents_dir/knowledge-engineer.md"
monolith="$refs_dir/docs-pipeline.md"

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
dangling="$(grep -rlF "docs-pipeline.md" "$agents_dir" "$commands_dir" "$refs_dir" "$skills_dir" 2>/dev/null | grep -vF "$monolith" || true)"
if [ -z "$dangling" ]; then
  echo "PASS: no dangling references — no live plugin source file under agents/commands/refs/skills still points at the removed docs-pipeline.md monolith"
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

if [ "$failures" -eq 0 ]; then
  echo "PASS: all docs-pipeline-slicing regression cases passed"
  exit 0
else
  echo "FAIL: $failures docs-pipeline-slicing regression case(s) failed"
  exit 1
fi
