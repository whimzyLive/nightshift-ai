#!/usr/bin/env bash
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
plugin="$here/../.."
policy="$plugin/refs/code-comments-policy.md"
qa="$plugin/refs/qa-engineer-playbook.md"
fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n     %s\n' "$1" "$2"; fail=1; }

comments_block() {
  awk '/^\*\*Comments\*\* — /{on=1} on&&/^$/{blank++; if (blank==2) exit} on{print}' "$1"
}

for heading in '## Never write' '## Allowed' '## Self-check before commit (implementers)' '## Review (QA gate)'; do
  grep -qxF "$heading" "$policy" && ok "policy has '$heading'" || bad "policy has '$heading'" "missing from $policy"
done

agents=()
for f in "$plugin"/agents/*.md; do
  grep -qF 'shared protocol for all domain' "$f" && agents+=("$f")
done
[ "${#agents[@]}" -ge 2 ] && ok "found ${#agents[@]} domain agents" || bad "found domain agents" "only ${#agents[@]}"

canon="$(comments_block "${agents[0]}")"
case "$canon" in
  *'${CLAUDE_PLUGIN_ROOT}/refs/code-comments-policy.md'*) ok "Comments block names the policy" ;;
  *) bad "Comments block names the policy" "$(basename "${agents[0]}") block has no policy path" ;;
esac

for f in "${agents[@]}"; do
  name="$(basename "$f" .md)"
  block="$(comments_block "$f")"
  if [ -z "$block" ]; then
    bad "$name carries the Comments block" "no '**Comments** — ' block"
  elif [ "$block" = "$canon" ]; then
    ok "$name Comments block matches $(basename "${agents[0]}" .md)"
  else
    bad "$name Comments block matches $(basename "${agents[0]}" .md)" "$(diff <(printf '%s\n' "$canon") <(printf '%s\n' "$block") | head -5)"
  fi
  grep -qF 'against the **Comments** rules (policy "Self-check before commit")' "$f" \
    && ok "$name completion checklist runs the self-check" \
    || bad "$name completion checklist runs the self-check" "self-check step missing"
done

n="$(grep -cF 'refs/code-comments-policy.md` Review' "$qa")"
m="$(grep -cF 'Review section of `${CLAUDE_PLUGIN_ROOT}/refs/code-comments-policy.md`' "$qa")"
[ "$n" -ge 1 ] && ok "QA severity points at the policy's Review section" \
  || bad "QA severity points at the policy's Review section" "not found in $qa"
[ "$m" -ge 1 ] && ok "QA reviewer dispatch points at the policy's Review section" \
  || bad "QA reviewer dispatch points at the policy's Review section" "not found in $qa"

grep -qiE 'informative/explanatory' "$qa" "${agents[@]}" \
  && bad "no surface keeps the old blanket ban wording" "$(grep -liE 'informative/explanatory' "$qa" "${agents[@]}" | xargs -n1 basename)" \
  || ok "no surface keeps the old blanket ban wording"

[ "$fail" -eq 0 ] && echo "PASS" || echo "FAIL"
exit "$fail"
