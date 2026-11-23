#!/usr/bin/env bash
# long-commands.test.sh — refs/long-commands.md exists with its Bash-tool facts, and every reader points at it.
#   bash plugins/sdlc/scripts/__tests__/long-commands.test.sh
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
plug="$here/../.."
ref="$plug/refs/long-commands.md"
pass=0 fail=0
ok() { pass=$((pass + 1)); echo "ok   $1"; }
bad() { fail=$((fail + 1)); echo "FAIL $1"; }
has() { grep -qF -- "$2" "$1"; }

[ -s "$ref" ] && ok "ref exists" || bad "ref exists"
for k in 'timeout` := 600000' 'run_in_background: true' 'never -> poll' 'never -> hand back'; do
  has "$ref" "$k" && ok "ref carries: $k" || bad "ref carries: $k"
done

for a in sync-engineer web-engineer database-administrator platform-engineer mobile-engineer ai-enablement-engineer; do
  has "$plug/agents/$a.md" 'refs/long-commands.md' && ok "$a points at the ref" || bad "$a points at the ref"
done
has "$plug/refs/qa-gate-runner.md" 'refs/long-commands.md' && ok "gate runner points at the ref" || bad "gate runner points at the ref"
has "$plug/refs/qa-review-rounds.md" 'never wait for a follow-up notification' && ok "review rounds carry the orchestrator rule" || bad "review rounds carry the orchestrator rule"
has "$plug/refs/bg-runs.md" 'is not a wait: no follow-up is coming' && ok "bg-runs carries the orchestrator rule" || bad "bg-runs carries the orchestrator rule"

echo "$pass passed, $fail failed"
[ "$fail" = 0 ]
