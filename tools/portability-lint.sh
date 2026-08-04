#!/usr/bin/env bash
#
# portability-lint — keeps every shipped plugin repo-agnostic and structurally valid.
#
# WHY THIS EXISTS
#   nightshift's whole promise is "install once, works in any repo." That only holds if the
#   plugin trees (plugins/*/**) contain ZERO machine- or project-specific details — no
#   absolute home paths, no author emails, no hardcoded org/stack tokens, no malformed manifests
#   or agents. It is easy for a contributor (or an AI agent) to paste their own machine's home
#   directory path or an `acme.atlassian.net` literal into an agent and silently break portability
#   for everyone
#   else. This lint is the CI gate that makes the generic-tier invariant enforceable instead of
#   aspirational. Project specifics belong in the CONSUMER repo's .claude/project/, never here.
#
# WHAT IT CHECKS per plugin under plugins/* (all run; non-zero exit if any fail)
#   1. No machine-absolute paths (a macOS/Linux home directory, a Windows drive letter, or the
#      Claude Code transcript-directory slug form with path separators turned into dashes)
#   2. No `./${CLAUDE_PLUGIN_ROOT}` (broken-path regression — the var is absolute)
#   3. No email addresses / author PII (placeholders like your-org@ are allowed)
#   4. Plugin agents declare no forbidden frontmatter (hooks / mcpServers / permissionMode)
#   5. Structure: every skill has SKILL.md; every agent & command has name+description frontmatter
#   6. Manifests are valid JSON (per-plugin plugin.json, plus the shared marketplace.json once)
#   7. Optional project-token denylist (tools/portability-denylist.txt) — one ERE per line,
#      `#` comments ignored. Empty/absent by default. Forks that dogfood the plugin in their own
#      org can list their tokens (company, Jira key, stack) here WITHOUT editing this script.
#
set -uo pipefail   # NOT -e: run every check, aggregate failures.

here="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$here/.." && pwd)"
plugins_dir="$(cd "$here/../plugins" && pwd)"
denylist="$here/portability-denylist.txt"
fail=0

# Shared machine-absolute-path pattern (used by check #1 below AND by lint_tree's non-plugin
# scan). Boundary group requires the char before the match not be a path/word char, otherwise
# an in-repo directory named e.g. `components/home/...` false-positives on `/home/[A-Za-z]`.
# The `-Users-[A-Za-z]` / `-home-[A-Za-z]` alternatives catch the Claude Code transcript-directory
# slug form, where `~/.claude/projects/<abs-path>` has every `/` turned into `-` — a plain
# `/Users/` grep never sees this shape.
MACH_PATH_RE='(^|[^A-Za-z0-9_./-])(/Users/[A-Za-z]|/home/[A-Za-z]|[A-Za-z]:\\)|-Users-[A-Za-z]|-home-[A-Za-z]'

# Known-legacy files predating this gate's tree-wide scan: they intentionally document a `cd`
# example command with one operator's own home-directory tree baked in, and are explicitly out
# of scope for cleanup (see NA-82 QA round). Do not add new entries here — a new file that
# needs a real absolute-path example should derive it at runtime or use a generic placeholder
# like `<encoded-repo-path>` instead (see docs/superpowers/plans/NA-81.md).
TREE_SCAN_ALLOWLIST=(
  "docs/superpowers/plans/NA-53.md"
  "docs/superpowers/plans/NA-54.md"
  "docs/superpowers/plans/NA-55.md"
  "docs/superpowers/plans/NA-56.md"
  "docs/superpowers/plans/NA-57.md"
  "docs/superpowers/plans/NA-60.md"
  "docs/superpowers/plans/NA-61.md"
  "docs/superpowers/plans/NA-62.md"
)

report() { # $1=name  $2=hits
  if [ -n "$2" ]; then
    echo "✗ $1"
    printf '%s\n' "$2" | sed 's/^/    /'
    fail=1
  else
    echo "✓ $1"
  fi
}

lint_plugin() { # $1=plugin root (absolute)
  local root="$1"
  local plugin_name
  plugin_name="$(basename "$root")"
  echo
  echo "-- plugin: $plugin_name --"

  # 1. machine-absolute paths (including the Claude Code transcript-directory slug form)
  report "no machine-absolute paths" \
    "$(grep -rInE "$MACH_PATH_RE" "$root" 2>/dev/null || true)"

  # 2. broken ./${CLAUDE_PLUGIN_ROOT}
  report "no ./\${CLAUDE_PLUGIN_ROOT} regression" \
    "$(grep -rIn '\./\${CLAUDE_PLUGIN_ROOT}' "$root" 2>/dev/null || true)"

  # 3. emails / PII (allow placeholder/example domains)
  report "no author emails / PII" \
    "$(grep -rInE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' "$root" 2>/dev/null \
       | grep -viE 'noreply|example\.|your-org|@your|ATLASSIAN_EMAIL|git@github\.com' || true)"

  # 4. forbidden plugin-agent frontmatter
  report "no forbidden agent frontmatter (hooks/mcpServers/permissionMode)" \
    "$(grep -rInE '^(hooks|mcpServers|permissionMode):' "$root/agents" 2>/dev/null || true)"

  # 5a. every skill has SKILL.md
  local missing_skill=""
  if [ -d "$root/skills" ]; then
    for d in "$root"/skills/*/; do
      [ -e "$d" ] || continue
      [ -f "${d}SKILL.md" ] || missing_skill+="${d} (no SKILL.md)"$'\n'
    done
  fi
  report "every skill has SKILL.md" "$(printf '%s' "$missing_skill")"

  # 5b. frontmatter: agents need name+description; commands need description (filename = name)
  local missing_fm=""
  for f in "$root"/agents/*.md; do
    [ -e "$f" ] || continue
    head -n 20 "$f" | grep -q '^name:'       || missing_fm+="$f (agent: no name:)"$'\n'
    head -n 20 "$f" | grep -q '^description:' || missing_fm+="$f (agent: no description:)"$'\n'
  done
  for f in "$root"/commands/*.md; do
    [ -e "$f" ] || continue
    head -n 20 "$f" | grep -q '^description:' || missing_fm+="$f (command: no description:)"$'\n'
  done
  report "agents have name+description, commands have description" "$(printf '%s' "$missing_fm")"

  # 6. plugin.json is valid JSON
  local bad_json=""
  local j="$root/.claude-plugin/plugin.json"
  if [ -f "$j" ]; then
    python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$j" 2>/dev/null \
      || bad_json+="$j (invalid JSON)"$'\n'
  else
    bad_json+="$j (missing)"$'\n'
  fi
  report "plugin.json is valid JSON" "$(printf '%s' "$bad_json")"

  # 7. optional project-token denylist
  if [ -f "$denylist" ]; then
    local pattern
    pattern="$(grep -vE '^\s*(#|$)' "$denylist" | paste -sd'|' -)"
    if [ -n "$pattern" ]; then
      report "no denylisted project tokens" \
        "$(grep -rInE "$pattern" "$root" 2>/dev/null || true)"
    else
      echo "• denylist present but empty — skipping token scan"
    fi
  else
    echo "• no tools/portability-denylist.txt — skipping optional token scan"
  fi
}

lint_tree() { # scans the tracked non-plugin tree — plugins/* has its own richer check #1 above
  echo
  echo "-- non-plugin tree: tools/, .claude/, docs/ --"

  local hits=""
  hits="$(cd "$repo_root" && git grep -InE "$MACH_PATH_RE" -- tools .claude docs 2>/dev/null || true)"

  local filtered=""
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    local allowed=0
    local allow
    for allow in "${TREE_SCAN_ALLOWLIST[@]}"; do
      case "$line" in
        "$allow":*) allowed=1; break ;;
      esac
    done
    [ "$allowed" -eq 1 ] || filtered+="$line"$'\n'
  done <<< "$hits"

  report "no machine-absolute or slug paths (tools/, .claude/, docs/)" "$(printf '%s' "$filtered")"
}

for root in "$plugins_dir"/*/; do
  [ -d "$root" ] || continue
  lint_plugin "${root%/}"
done

lint_tree

# shared marketplace.json — checked once, not per plugin
echo
echo "-- shared manifest --"
marketplace="$here/../.claude-plugin/marketplace.json"
if [ -f "$marketplace" ]; then
  python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$marketplace" 2>/dev/null \
    && report "marketplace.json is valid JSON" "" \
    || report "marketplace.json is valid JSON" "$marketplace (invalid JSON)"
else
  report "marketplace.json is valid JSON" "$marketplace (missing)"
fi

echo
if [ "$fail" -ne 0 ]; then
  echo "portability-lint: FAILED"
  exit 1
fi
echo "portability-lint: clean"
