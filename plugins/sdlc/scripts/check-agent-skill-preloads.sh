#!/usr/bin/env bash
# check-agent-skill-preloads.sh — guards against frontmatter `skills:` preloads on SDLC agents.
#
# WHY THIS EXISTS (NA-25)
#   Upstream harness bug (anthropics/claude-code#76337): every SendMessage resume of a subagent
#   re-injects the FULL TEXT of every frontmatter `skills:` preload — ~8k tokens per resume,
#   verified byte-identical duplicates. Every agent under plugins/sdlc/agents/*.md that declares a
#   frontmatter `skills:` key pays this tax on each resume. The verified workaround is to load
#   skills via explicit Skill-tool calls in the agent's own first turn instead (immune to
#   re-injection) rather than declaring them in frontmatter.
#
#   This script is a regression guard: it fails loudly while any agent still declares frontmatter
#   `skills:`, and stays green once every agent has been converted to first-turn Skill-tool loads.
#
# WHAT IT CHECKS
#   Two checks, both must pass:
#   1. NEGATIVE — for every plugins/sdlc/agents/*.md, parse ONLY the YAML frontmatter block — the
#      content between the first `---` line and the next `---` line. A `skills:` key found there
#      is an offender. The body of the file may legitimately mention the word "skills:" in prose
#      or code fences (e.g. explaining the Skill-tool workaround) — that must never trip this check.
#   2. POSITIVE — every plugins/sdlc/agents/*.md must contain, verbatim on one physical line, the
#      first-turn Skill-tool load marker sentence (see MARKER below). This proves the agent was
#      actually converted, not just stripped of its frontmatter `skills:` block. A file missing the
#      marker is an offender even if it has zero frontmatter `skills:`.
#
# USAGE
#   bash plugins/sdlc/scripts/check-agent-skill-preloads.sh
#   Exit 0 + "OK" when every agent passes both checks.
#   Exit 1 + a listing of offending files when one or more fail either check.

set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
agents_dir="$here/../agents"

# Fail fast if the agents dir is missing — with `set -uo pipefail` (no `-e`), a failed `cd` in a
# command substitution does NOT stop the script; it silently produces an empty $agents_dir, which
# then makes the loop below glob against `/*.md` (repo root) and find nothing. Checking `-d`
# explicitly, before resolving the absolute path, catches that case loudly instead of letting the
# rest of the script run against the wrong directory.
if [ ! -d "$agents_dir" ]; then
  echo "check-agent-skill-preloads: FAILED — agents directory not found at $agents_dir" >&2
  exit 1
fi
agents_dir="$(cd "$agents_dir" && pwd)"

# nullglob so a no-match glob expands to zero elements (an empty array) instead of the literal,
# non-existent path "$agents_dir/*.md" — without it, the fail-fast check below would never see an
# empty match and the guard would stay vacuously green on an empty agents dir.
shopt -s nullglob
files=("$agents_dir"/*.md)
shopt -u nullglob

if [ "${#files[@]}" -eq 0 ]; then
  echo "check-agent-skill-preloads: FAILED — no agent .md files found in $agents_dir" >&2
  exit 1
fi

# The literal first-turn Skill-tool load marker every converted agent must carry, verbatim on one
# physical line (see the "Required skills" sections in plugins/sdlc/agents/*.md). Grepped with
# `grep -F` (fixed-string) so em dashes and punctuation are matched literally, not as regex.
marker='Before any implementation work — after your pre-flight/step-0 checks, and skipped entirely on an early abort — load each of these via the Skill tool:'

preload_offenders=""
marker_offenders=""

for f in "${files[@]}"; do
  # Extract the frontmatter block: everything between the first `---` line and the next `---`
  # line — anchored so the OPENING delimiter must be line 1. Without that anchor, a frontmatter-less
  # file whose body happens to contain two `---` horizontal rules (with a `skills:`-looking line
  # between them) would be mis-parsed as if that body span were frontmatter, false-positiving the
  # check below. Anchoring to NR==1 means a file with no real frontmatter block yields nothing here.
  frontmatter="$(awk '
    NR==1 && /^---[[:space:]]*$/ { open=1; next }
    NR==1 { exit }
    open && /^---[[:space:]]*$/ { exit }
    open { print }
  ' "$f")"

  if printf '%s\n' "$frontmatter" | grep -qE '^skills:'; then
    preload_offenders+="$f"$'\n'
  fi

  if ! grep -qF "$marker" "$f"; then
    marker_offenders+="$f"$'\n'
  fi
done

fail=0

if [ -n "$preload_offenders" ]; then
  fail=1
  echo "check-agent-skill-preloads: FAILED (frontmatter skills: preload)"
  echo
  echo "The following agents declare a frontmatter 'skills:' preload, which the harness"
  echo "re-injects in full (~8k tokens/resume, byte-identical duplicates) on every SendMessage"
  echo "resume — see NA-25 / anthropics/claude-code#76337:"
  echo
  printf '%s' "$preload_offenders" | sed 's/^/  - /'
  echo
  echo "Fix: convert the agent to load these skills via explicit Skill-tool calls in its own"
  echo "first turn instead of declaring them in frontmatter 'skills:' — immune to re-injection."
  echo
fi

if [ -n "$marker_offenders" ]; then
  fail=1
  echo "check-agent-skill-preloads: FAILED (missing first-turn Skill-tool load marker)"
  echo
  echo "The following agents are missing the first-turn Skill-tool load marker sentence, so"
  echo "there's no proof they were actually converted (not just stripped of frontmatter skills:):"
  echo
  printf '%s' "$marker_offenders" | sed 's/^/  - /'
  echo
  echo "Fix: add a \"Required skills\" section whose lead-in is, verbatim on one line:"
  echo "  $marker"
  echo
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "check-agent-skill-preloads: OK — no agent declares frontmatter skills:, and every agent carries the first-turn Skill-tool load marker"
exit 0
