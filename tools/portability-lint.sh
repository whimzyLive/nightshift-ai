#!/usr/bin/env bash
#
# portability-lint — keeps every shipped plugin repo-agnostic and structurally valid.
#
# WHY THIS EXISTS
#   nightshift's whole promise is "install once, works in any repo." That only holds if the
#   plugin trees (plugins/*/**) contain ZERO machine- or project-specific details — no
#   absolute home paths, no author emails, no hardcoded org/stack tokens, no malformed manifests
#   or agents. It is easy for a contributor (or an AI agent) to paste a `/Users/you/...` path or
#   an `acme.atlassian.net` literal into an agent and silently break portability for everyone
#   else. This lint is the CI gate that makes the generic-tier invariant enforceable instead of
#   aspirational. Project specifics belong in the CONSUMER repo's .claude/project/, never here.
#
# WHAT IT CHECKS per plugin under plugins/* (all run; non-zero exit if any fail)
#   1. No machine-absolute paths (/Users/…, /home/<user>/…, C:\…)
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
plugins_dir="$(cd "$here/../plugins" && pwd)"
denylist="$here/portability-denylist.txt"
fail=0

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

  # 1. machine-absolute paths
  report "no machine-absolute paths" \
    "$(grep -rInE '/Users/|/home/[A-Za-z]|[A-Za-z]:\\\\' "$root" 2>/dev/null || true)"

  # 2. broken ./${CLAUDE_PLUGIN_ROOT}
  report "no ./\${CLAUDE_PLUGIN_ROOT} regression" \
    "$(grep -rIn '\./\${CLAUDE_PLUGIN_ROOT}' "$root" 2>/dev/null || true)"

  # 3. emails / PII (allow placeholder/example domains)
  report "no author emails / PII" \
    "$(grep -rInE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' "$root" 2>/dev/null \
       | grep -viE 'noreply|example\.|your-org|@your|ATLASSIAN_EMAIL' || true)"

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

for root in "$plugins_dir"/*/; do
  [ -d "$root" ] || continue
  lint_plugin "${root%/}"
done

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
