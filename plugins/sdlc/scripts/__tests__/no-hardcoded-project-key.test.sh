#!/usr/bin/env bash
# no-hardcoded-project-key.test.sh — regression test pinning the `--project ET` literal removal
# (NA-78).
#
# Checks, scoped to plugins/sdlc/commands/ and plugins/sdlc/agents/:
#   1. No literal Jira project key as a `--project`/`-p` value, in any quoting/`=` form (matcher
#      rationale: .claude/memories/agents/ai-enablement-engineer/grep-guard-must-cover-flag-form-variants.md).
#   2. refine-feature.md's unresolvable-key STOP is present, co-located with the project-key
#      resolution instruction, and does not permit a fallback (matcher rationale:
#      .claude/memories/agents/ai-enablement-engineer/awk-rs-paragraph-proximity-for-colocation-assertions.md).
#
# Self-runnable, no test harness/framework dependency:
#   bash plugins/sdlc/scripts/__tests__/no-hardcoded-project-key.test.sh
# Exit 0 = PASS (all cases), non-zero = FAIL (any case).
set -uo pipefail

here="${BASH_SOURCE[0]%/*}"; [ "$here" = "${BASH_SOURCE[0]}" ] && here="."
plugin_root="$(cd "$here/../.." && pwd)"
commands_dir="$plugin_root/commands"
agents_dir="$plugin_root/agents"
refine_feature="$commands_dir/refine-feature.md"

failures=0

if [ ! -d "$commands_dir" ] || [ ! -d "$agents_dir" ]; then
  echo "FAIL: setup — commands_dir=$commands_dir or agents_dir=$agents_dir not found"
  echo "FAIL: 1 no-hardcoded-project-key regression case(s) failed"
  exit 1
fi

# Case 1
project_flag_re='(--project|(^|[[:space:]])-p)([[:space:]]+|=)["'"'"']?[A-Z][A-Z0-9]{1,9}'
hardcoded_hits="$(grep -rnE -- "$project_flag_re" "$commands_dir" "$agents_dir" 2>/dev/null || true)"
if [ -z "$hardcoded_hits" ]; then
  echo "PASS: grep-clean — no hardcoded --project/-p literal under plugins/sdlc/commands/ or plugins/sdlc/agents/"
else
  echo "FAIL: grep-clean — found hardcoded --project/-p literal(s):"
  printf '%s\n' "$hardcoded_hits" | sed 's/^/    /'
  failures=$((failures + 1))
fi

# Case 2
stop_para="$(awk -v RS="" 'tolower($0) ~ /stop/ && tolower($0) ~ /project key/ && $0 ~ /project-context\.md/ {print; exit}' "$refine_feature" 2>/dev/null)"
no_fallback_re='not fall back|never fall back|do not default|never default|not default'
literal_default_re='(default(ing)?[[:space:]]+to|fallback[[:space:]]+(to|is))[[:space:]]+["'"'"']?[A-Z]{2,10}'
if [ -n "$stop_para" ] \
  && printf '%s' "$stop_para" | grep -qiE -- "$no_fallback_re" \
  && ! printf '%s' "$stop_para" | grep -qiE -- "$literal_default_re"; then
  echo "PASS: STOP instruction — refine-feature.md has a co-located, no-fallback STOP paragraph"
else
  echo "FAIL: STOP instruction — refine-feature.md has no co-located, no-fallback STOP paragraph"
  failures=$((failures + 1))
fi

if [ "$failures" -eq 0 ]; then
  echo "PASS: all no-hardcoded-project-key regression cases passed"
  exit 0
else
  echo "FAIL: $failures no-hardcoded-project-key regression case(s) failed"
  exit 1
fi
