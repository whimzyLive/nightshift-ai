#!/usr/bin/env bash
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
plugin="$here/../.."
policy="$plugin/refs/code-comments-policy.md"
qa="$plugin/refs/qa-engineer-playbook.md"
loop_modes="$plugin/refs/loop-modes.md"
implementers="ai-enablement-engineer database-administrator mobile-engineer platform-engineer sync-engineer web-engineer"
exempt="knowledge-engineer"
fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n     %s\n' "$1" "$2"; fail=1; }

section() {
  awk -v h="$2" '$0==h{on=1; next} on&&/^## /{exit} on{print}' "$1"
}

comments_block() {
  awk '/^\*\*Comments\*\* — /{on=1} on&&/^## /{exit} on{print}' "$1"
}

for heading in '## Scope' '## Never write' '## Allowed' '## Self-check before commit (implementers)' '## Review (QA gate and PR-loop reviewer)'; do
  grep -qxF "$heading" "$policy" && ok "policy has '$heading'" || bad "policy has '$heading'" "missing from $policy"
done

kinds="$(section "$policy" '## Never write' | awk -F'|' '/^\| / && $2 !~ /^ *Kind *$/ {gsub(/^ +| +$/, "", $2); print $2}')"
nkinds="$(printf '%s\n' "$kinds" | grep -c .)"
[ "$nkinds" -ge 5 ] && ok "policy Never-write table has $nkinds kinds" \
  || bad "policy Never-write table has kinds" "only $nkinds rows parsed"

first="$plugin/agents/${implementers%% *}.md"
if [ ! -f "$first" ]; then
  bad "canonical agent exists" "$first not found"
  echo "FAIL"; exit 1
fi
canon="$(comments_block "$first")"
case "$canon" in
  *'${CLAUDE_PLUGIN_ROOT}/refs/code-comments-policy.md'*) ok "Comments block names the policy" ;;
  *) bad "Comments block names the policy" "$(basename "$first") block has no policy path" ;;
esac
while IFS= read -r kind; do
  [ -n "$kind" ] || continue
  printf '%s\n' "$canon" | grep -qiF -- "$kind" && ok "Comments block names Never-write kind '$kind'" \
    || bad "Comments block names Never-write kind '$kind'" "short form omits a kind QA blocks on"
done <<EOF
$kinds
EOF

for name in $implementers; do
  f="$plugin/agents/$name.md"
  if [ ! -f "$f" ]; then
    bad "$name exists" "$f not found"
    continue
  fi
  block="$(comments_block "$f")"
  if [ -z "$block" ]; then
    bad "$name carries the Comments block" "no '**Comments** — ' block"
  elif [ "$block" = "$canon" ]; then
    ok "$name Comments block matches ${implementers%% *}"
  else
    bad "$name Comments block matches ${implementers%% *}" "$(diff <(printf '%s\n' "$canon") <(printf '%s\n' "$block") | head -5)"
  fi
  section "$f" '## Completion checklist' | grep -qF '**Comments** rules (policy "Self-check before commit")' \
    && ok "$name completion checklist runs the self-check" \
    || bad "$name completion checklist runs the self-check" "no self-check step under '## Completion checklist'"
done

for f in "$plugin"/agents/*.md; do
  name="$(basename "$f" .md)"
  case " $implementers $exempt " in *" $name "*) continue ;; esac
  grep -qF 'domain-agent-handoff.md' "$f" \
    && bad "$name is classified" "follows domain-agent-handoff.md but is neither an implementer nor exempt in this test"
  if grep -q '^\*\*Comments\*\* — ' "$f" && [ "$(comments_block "$f")" != "$canon" ]; then
    bad "$name Comments block matches ${implementers%% *}" "a non-implementer carries a diverging copy"
  fi
done

grep -qF 'Review section of `${CLAUDE_PLUGIN_ROOT}/refs/code-comments-policy.md`' "$qa" \
  && ok "QA reviewer dispatch points at the policy's Review section" \
  || bad "QA reviewer dispatch points at the policy's Review section" "not found in $qa"
grep -qF '`${CLAUDE_PLUGIN_ROOT}/refs/code-comments-policy.md` Review. Same rules both sides.' "$qa" \
  && ok "QA severity points at the policy's Review section" \
  || bad "QA severity points at the policy's Review section" "not found in $qa"
grep -qF 'run your **Comments**' "$qa" \
  && ok "QA fix-round prompt runs the Comments self-check" \
  || bad "QA fix-round prompt runs the Comments self-check" "not found in $qa"
grep -qF '`${CLAUDE_PLUGIN_ROOT}/refs/code-comments-policy.md` Review' "$loop_modes" \
  && ok "PR-loop reviewer points at the policy's Review section" \
  || bad "PR-loop reviewer points at the policy's Review section" "not found in $loop_modes"

stale="$(grep -rliE 'informative/explanatory' "$plugin/agents" "$plugin/refs" "$plugin/commands" "$plugin/skills" 2>/dev/null)"
[ -z "$stale" ] && ok "no surface keeps the old blanket ban wording" \
  || bad "no surface keeps the old blanket ban wording" "$stale"

[ "$fail" -eq 0 ] && echo "PASS" || echo "FAIL"
exit "$fail"
