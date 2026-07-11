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
#   For every plugins/sdlc/agents/*.md, parse ONLY the YAML frontmatter block — the content
#   between the first `---` line and the next `---` line. A `skills:` key found there is an
#   offender. The body of the file may legitimately mention the word "skills:" in prose or code
#   fences (e.g. explaining the Skill-tool workaround) — that must never trip this check.
#
# USAGE
#   bash plugins/sdlc/scripts/check-agent-skill-preloads.sh
#   Exit 0 + "OK" when zero agents declare frontmatter skills:.
#   Exit 1 + a listing of offending files when one or more do.

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

offenders=""

for f in "${files[@]}"; do
  # Extract the frontmatter block: everything between the first `---` line and the next `---`
  # line. awk stops emitting once it hits the closing delimiter, so body prose/code fences that
  # happen to contain the literal text "skills:" are never considered.
  frontmatter="$(awk '
    /^---[[:space:]]*$/ { delim++; if (delim == 2) exit; next }
    delim == 1 { print }
  ' "$f")"

  if printf '%s\n' "$frontmatter" | grep -qE '^skills:'; then
    offenders+="$f"$'\n'
  fi
done

if [ -n "$offenders" ]; then
  echo "check-agent-skill-preloads: FAILED"
  echo
  echo "The following agents declare a frontmatter 'skills:' preload, which the harness"
  echo "re-injects in full (~8k tokens/resume, byte-identical duplicates) on every SendMessage"
  echo "resume — see NA-25 / anthropics/claude-code#76337:"
  echo
  printf '%s' "$offenders" | sed 's/^/  - /'
  echo
  echo "Fix: convert the agent to load these skills via explicit Skill-tool calls in its own"
  echo "first turn instead of declaring them in frontmatter 'skills:' — immune to re-injection."
  exit 1
fi

echo "check-agent-skill-preloads: OK — no agent declares frontmatter skills:"
exit 0
