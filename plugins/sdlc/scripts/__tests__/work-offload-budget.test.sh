#!/usr/bin/env bash
# work-offload-budget.test.sh — NA-92 guard for the work-offload budget and the relocation contract.
#
# AUTHOR-RUN AND CI-WIRED:
#   bash plugins/sdlc/scripts/__tests__/work-offload-budget.test.sh
# Exit 0 = PASS, exit 1 = FAIL.
#
# NA-88 D11 — this guard is authored by the same story that authors the text under test.
# A pass proves the author wrote what the author intended and that every assertion is wired to
# something that can move. It is a SMOKE TEST on the artifact, never a gate on agent behaviour.
# Only assertion (c) is a real gate, and it gates the BUDGET CLAIM, not the contract's observance.
# The pilot (a story NA-92 does not author) is the only evidence about the contract itself.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$here/../../../.."
refs="$root/plugins/sdlc/refs"
qa="$refs/qa-engineer-playbook.md"
pe="$refs/principal-engineer-playbook.md"
runner="$refs/qa-gate-runner.md"
verifier="$refs/ac-verification.md"
handoff="$refs/domain-agent-handoff.md"
fail=0

ok()   { printf 'ok   %s\n' "$1"; }
bad()  { printf 'FAIL %s\n     %s\n' "$1" "$2"; fail=1; }

# section_bytes <file> <heading>  -> bytes from the heading to the next top-level heading
section_bytes() {
  awk -v h="$2" '$0==h{f=1} f&&/^## /&&$0!=h{exit} f' "$1" | wc -c | tr -d ' '
}

# --- (a) the runner ref exists and carries its return contract verbatim ------------
[ -s "$runner" ] || bad "(a) qa-gate-runner.md exists and is non-empty" "missing or empty: $runner"
for k in 'Gate:' 'Commands:' 'Evidence:' 'Failing workspace:' 'Owning agent:' 'Error:' 'Stray files:'; do
  grep -qF -- "$k" "$runner" && ok "(a) runner carries key $k" \
    || bad "(a) runner carries key $k" "return contract key absent"
done

# --- (b) the verifier ref exists and carries its return contract verbatim ----------
[ -s "$verifier" ] || bad "(b) ac-verification.md exists and is non-empty" "missing or empty: $verifier"
for k in 'Verification:' 'AC-<n>:' 'Plan task <n>:' 'Regression evidence:' 'Unmet:' 'Owner:'; do
  grep -qF -- "$k" "$verifier" && ok "(b) verifier carries key $k" \
    || bad "(b) verifier carries key $k" "return contract key absent"
done

# --- (c) THE GATE: combined impl-path instruction surface -------------------------
qa_b="$(wc -c < "$qa" | tr -d ' ')"
pe_b="$(wc -c < "$pe" | tr -d ' ')"
tot=$((qa_b + pe_b))
[ "$tot" -le 73704 ] && ok "(c) combined playbooks $tot <= 73704" \
  || bad "(c) combined playbooks <= 73704" "actual $tot (qa=$qa_b pe=$pe_b) — NEVER raise this constant"

# --- (d) each rewritten step names its offload target -----------------------------
grep -qF -- 'refs/qa-gate-runner.md' "$qa"    && ok "(d) QA Step 6 names the runner ref" \
  || bad "(d) QA Step 6 names the runner ref" "qa-engineer-playbook.md does not reference refs/qa-gate-runner.md"
grep -qF -- 'refs/ac-verification.md' "$qa"   && ok "(d) QA Step 7 names the verifier ref" \
  || bad "(d) QA Step 7 names the verifier ref" "qa-engineer-playbook.md does not reference refs/ac-verification.md"
grep -qF -- 'scripts/docs-sync-gate.sh' "$pe" && ok "(d) PE Step 6.5 names the gate script" \
  || bad "(d) PE Step 6.5 names the gate script" "principal-engineer-playbook.md does not reference scripts/docs-sync-gate.sh"

# --- (e) the moved mechanics are ABSENT, not duplicated ---------------------------
# Tokens verified unique at 49489bf: each occurs exactly once, in the moved block, and zero
# times in the sibling playbook. Re-verify before changing one.
for t in 'phase-3-sha' 'infra build with the stage flag' 'before the quality gate'; do
  grep -qF -- "$t" "$qa" && bad "(e) QA no longer contains '$t'" "moved mechanics still inline" \
    || ok "(e) QA no longer contains '$t'"
done
for t in 'reference-roots' 'git diff --name-only' 'docs-pipeline-core'; do
  grep -qF -- "$t" "$pe" && bad "(e) PE no longer contains '$t'" "moved gate prose still inline" \
    || ok "(e) PE no longer contains '$t'"
done

# --- (f) the three offloaded sections, together (A8) ------------------------------
s6="$(section_bytes "$qa" '## Step 6 — Quality gate')"
s7="$(section_bytes "$qa" '## Step 7 — Verification before completion (AC + plan check)')"
s65="$(section_bytes "$pe" '## Step 6.5 — Post-QA docs sync (on a clean QA verdict, before the PR)')"
three=$((s6 + s7 + s65))
[ "$three" -le 7373 ] && ok "(f) three offloaded sections $three <= 7373" \
  || bad "(f) three offloaded sections <= 7373" "actual $three (s6=$s6 s7=$s7 s6.5=$s65)"

# --- (g) NA-88 and NA-90's byte pins are intact — G must not touch them ------------
cr="$(section_bytes "$handoff" '## Context reuse')"
br="$(section_bytes "$handoff" '## Bounded reads')"
[ "$cr" -eq 868 ]  && ok "(g) ## Context reuse pinned at 868" \
  || bad "(g) ## Context reuse == 868 (NA-88, hard equality)" "actual $cr"
[ "$br" -le 1005 ] && ok "(g) ## Bounded reads <= 1005" \
  || bad "(g) ## Bounded reads <= 1005 (NA-90)" "actual $br"

exit "$fail"
