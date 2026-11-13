#!/usr/bin/env bash
# skills-for.test.sh — pins scripts/skills-for.sh: contract/manifest merge precedence, the mode and
# path filters, the v1 fallback, unknown agents and the empty result. Hermetic: temp manifests.
#   bash plugins/sdlc/scripts/__tests__/skills-for.test.sh
set -uo pipefail

here="${BASH_SOURCE[0]%/*}"; [ "$here" = "${BASH_SOURCE[0]}" ] && here="."
sf="$(cd "$here/.." && pwd)/skills-for.sh"
shipped_contract="$(cd "$here/../../refs" && pwd)/skills-contract.json"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
failures=0
check() { if [ "$2" = "$3" ]; then echo "ok   - $1"; else echo "FAIL - $1: expected '$2', got '$3'"; failures=$((failures + 1)); fi; }
run() { bash "$sf" "$@" 2>"$work/err"; }
rc_of() { bash "$sf" "$@" >/dev/null 2>"$work/err"; echo $?; }

cat >"$work/contract.json" <<'JSON'
{ "version": 2, "skills": [
  { "name": "writing-specs", "agents": ["solutions-architect"], "required": true, "when": { "step": "before writing the spec" } },
  { "name": "conventional-commit", "agents": ["web-engineer", "platform-engineer"], "required": true, "when": { "step": "before each commit" } },
  { "name": "user-story-mapping", "agents": ["scrum-master"], "required": true, "when": { "mode": ["decompose"] } }
] }
JSON
no_manifest="$work/none.json"

check "contract row for its agent" \
  "SKILL=writing-specs REQUIRED=yes STEP=before writing the spec" \
  "$(run solutions-architect --manifest "$no_manifest" --contract "$work/contract.json")"
check "agent with no rows: empty output" "" "$(run tech-lead --manifest "$no_manifest" --contract "$work/contract.json")"
check "agent with no rows: exit 0" 0 "$(rc_of tech-lead --manifest "$no_manifest" --contract "$work/contract.json")"

cat >"$work/m2.json" <<'JSON'
{ "version": 2, "skills": [
  { "name": "conventional-commit", "source": "custom", "addedBy": "init", "agents": ["platform-engineer"], "required": false, "when": { "step": "when committing" } },
  { "name": "golang-testing", "source": "custom", "addedBy": "init", "agents": ["platform-engineer"], "required": true,
    "when": { "paths": ["backend/**"], "step": "before writing or changing a test" } },
  { "name": "react-components", "source": "custom", "addedBy": "init", "agents": ["web-engineer"], "required": true,
    "when": { "paths": ["apps/web/**", "packages/ui/**"] } },
  { "name": "tracked-only", "source": "custom", "addedBy": "init", "agents": [] }
] }
JSON
args=(--manifest "$work/m2.json" --contract "$work/contract.json")

check "repo row replaces contract row entirely" \
  "SKILL=conventional-commit REQUIRED=no STEP=when committing" \
  "$(run platform-engineer "${args[@]}" --paths other/ | grep conventional-commit)"
check "a replaced row drops the agents the repo row does not name" "" \
  "$(run web-engineer "${args[@]}" --paths other/ | grep conventional-commit)"
check "repo-only row appended" 1 "$(run platform-engineer "${args[@]}" | grep -c '^SKILL=golang-testing REQUIRED=yes STEP=before writing or changing a test$')"
check "absent step prints -" "SKILL=react-components REQUIRED=yes STEP=-" "$(run web-engineer "${args[@]}")"
check "empty agents is tracked only" 0 "$(run platform-engineer "${args[@]}" | grep -c tracked-only)"

check "path filter: dispatch path inside the glob matches" 1 "$(run platform-engineer "${args[@]}" --paths backend/internal/x.go | grep -c golang-testing)"
check "path filter: owned directory containing the glob matches" 1 "$(run platform-engineer "${args[@]}" --paths backend/ | grep -c golang-testing)"
check "path filter: parent of the glob prefix matches" 1 "$(run web-engineer "${args[@]}" --paths apps/ | grep -c react-components)"
check "path filter: unrelated path does not match" 0 "$(run platform-engineer "${args[@]}" --paths infra/,docs/ | grep -c golang-testing)"
check "path filter: any of several paths matches" 1 "$(run platform-engineer "${args[@]}" --paths infra/,backend/ | grep -c golang-testing)"
check "path filter: no --paths matches conservatively" 1 "$(run platform-engineer "${args[@]}" | grep -c golang-testing)"

check "mode filter: listed mode matches" "SKILL=user-story-mapping REQUIRED=yes STEP=-" \
  "$(run scrum-master "${args[@]}" --mode decompose)"
check "mode filter: other mode does not match" "" "$(run scrum-master "${args[@]}" --mode triage)"
check "mode filter: no --mode does not match a mode-gated row" "" "$(run scrum-master "${args[@]}")"

check "print-prompt header" \
  "Skills for this dispatch (invoke each with the Skill tool at the step named, never earlier):" \
  "$(run solutions-architect --manifest "$no_manifest" --contract "$work/contract.json" --print-prompt | sed -n 1p)"
check "print-prompt required wording" "- writing-specs — required: before writing the spec" \
  "$(run solutions-architect --manifest "$no_manifest" --contract "$work/contract.json" --print-prompt | sed -n 2p)"
check "print-prompt optional wording" "- conventional-commit — optional: if committing applies" \
  "$(run platform-engineer "${args[@]}" --print-prompt | grep conventional-commit)"
check "print-prompt empty result is empty" "" "$(run tech-lead "${args[@]}" --print-prompt)"

cat >"$work/v1.json" <<'JSON'
{ "version": 1, "skills": [ { "name": "conventional-commit", "source": "custom", "addedBy": "init" }, { "name": "old-skill", "source": "custom", "addedBy": "init" } ] }
JSON
v1=(--manifest "$work/v1.json" --contract "$work/contract.json")
check "v1: tracked-only rows are not injected" 0 "$(run platform-engineer "${v1[@]}" | grep -c old-skill)"
check "v1: contract rows still apply" 1 "$(run platform-engineer "${v1[@]}" | grep -c conventional-commit)"
check "v1: warns on stderr" "WARN: skills.json is v1 — run /sdlc:init to upgrade" "$(run platform-engineer "${v1[@]}" >/dev/null; cat "$work/err")"
check "v1: exit 0" 0 "$(rc_of platform-engineer "${v1[@]}")"

check "unknown agent argument exits 2" 2 "$(rc_of nope "${args[@]}")"
cat >"$work/bad-agent.json" <<'JSON'
{ "version": 2, "skills": [ { "name": "x", "agents": ["not-an-agent"] } ] }
JSON
check "unknown agent in the manifest exits 2" 2 "$(rc_of platform-engineer --manifest "$work/bad-agent.json" --contract "$work/contract.json")"
check "unknown agent in the manifest names it" 1 "$(grep -c "not-an-agent" "$work/err")"
printf '{ nope' >"$work/bad-json.json"
check "bad JSON exits 2" 2 "$(rc_of platform-engineer --manifest "$work/bad-json.json" --contract "$work/contract.json")"
printf '{ "version": 3, "skills": [] }' >"$work/v3.json"
check "version 3 exits 2" 2 "$(rc_of platform-engineer --manifest "$work/v3.json" --contract "$work/contract.json")"
check "unknown flag exits 2" 2 "$(rc_of platform-engineer --bogus)"
check "missing agent exits 2" 2 "$(rc_of)"
check "missing contract exits 2" 2 "$(rc_of platform-engineer --manifest "$no_manifest" --contract "$work/absent.json")"

check "shipped contract is valid and resolves for every agent" 0 \
  "$(for a in $(ls "$(dirname "$sf")/../agents" | sed 's/\.md$//'); do bash "$sf" "$a" --manifest "$no_manifest" --contract "$shipped_contract" >/dev/null 2>&1 || echo bad; done | wc -l | tr -d ' ')"
check "shipped contract: solutions-architect gets writing-specs" 1 \
  "$(run solutions-architect --manifest "$no_manifest" --contract "$shipped_contract" | grep -c '^SKILL=writing-specs ')"
check "shipped contract: scrum-master decompose gets both story skills" 2 \
  "$(run scrum-master --manifest "$no_manifest" --contract "$shipped_contract" --mode decompose | grep -c '^SKILL=user-story-')"
check "shipped contract: knowledge-engineer seed-adr gets writing-adrs, not writing-docs" "1 0" \
  "$(o="$(run knowledge-engineer --manifest "$no_manifest" --contract "$shipped_contract" --mode seed-adr)"; echo "$(grep -c writing-adrs <<<"$o") $(grep -c writing-docs <<<"$o")")"

if [ "$failures" -eq 0 ]; then echo "PASS: skills-for"; exit 0; fi
echo "FAIL: $failures skills-for case(s) failed"; exit 1
