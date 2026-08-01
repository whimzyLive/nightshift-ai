#!/usr/bin/env bash
# plan-slice-contract.test.sh — NA-81 Phase 3. Gates G-16 (principal-engineer-playbook.md's
# contract: the harvested duplicate is gone, the old paste-instruction is gone, the invocation
# is present), G-17 (domain-agent-handoff.md's byte-pinned sections are untouched and the new
# ## Plan slice clause exists), and G-18 (ac-verification.md checklist item 1 sources the
# checklist-mode slice).
#
# AUTHOR-RUN AND CI-WIRED:
#   bash plugins/sdlc/scripts/__tests__/plan-slice-contract.test.sh
# Exit 0 = PASS, exit 1 = FAIL.
#
# Every extraction below is a NAMED FIELD (an awk-bounded section, or a single grep token
# re-verified unique before being trusted) — never a whole-blob grep. See the plan's
# Falsifiability register: a grep or substring check over a whole blob is the shape that has
# already produced dead assertions on this epic.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$here/../../../.."
refs="$root/plugins/sdlc/refs"
pe="$refs/principal-engineer-playbook.md"
handoff="$refs/domain-agent-handoff.md"
ac="$refs/ac-verification.md"
fail=0

ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n     %s\n' "$1" "$2"; fail=1; }

# --- G-16: PE contract, three separate token assertions ---------------------------
# NOTE: the plan's own candidate token 'pass them verbatim into' is NOT unique in this file —
# it also names the lightweight path's own "treat the acceptance criteria as the completion
# contract" sentence (line ~155), independent of the harvested passage. Re-verified with
# grep -c against develop before writing this assertion; using the harvest's own unique
# substring instead, per the plan's own re-verify-before-trusting instruction (Task 3.3 Step 1).
harvest_count="$(grep -c 'Note any "grounding corrections"' "$pe" || true)"
[ "${harvest_count:-0}" -eq 0 ] && ok "(G-16a) harvested duplicate note is gone" \
  || bad "(G-16a) harvested duplicate note is gone" "grep -c returned $harvest_count, expected 0"

old_count="$(grep -c 'The full phase section from the plan, verbatim' "$pe" || true)"
[ "${old_count:-0}" -eq 0 ] && ok "(G-16b) old paste-the-phase item-4 wording is gone" \
  || bad "(G-16b) old paste-the-phase item-4 wording is gone" "grep -c returned $old_count, expected 0"

slicer_count="$(grep -c 'scripts/plan-slice.sh' "$pe" || true)"
[ "${slicer_count:-0}" -ge 1 ] && ok "(G-16c) plan-slice.sh invocation present ($slicer_count)" \
  || bad "(G-16c) plan-slice.sh invocation present" "grep -c returned $slicer_count, expected >= 1"

# --- G-17: handoff pins + the new clause, extracted --------------------------------
context_reuse_bytes="$(awk '/^## Context reuse$/{f=1} f&&/^## /&&!/^## Context reuse$/{exit} f' "$handoff" | wc -c | tr -d ' ')"
[ "$context_reuse_bytes" -eq 868 ] && ok "(G-17a) ## Context reuse == 868 B" \
  || bad "(G-17a) ## Context reuse == 868 B" "actual $context_reuse_bytes"

bounded_reads_bytes="$(awk '/^## Bounded reads$/{f=1} f&&/^## /&&!/^## Bounded reads$/{exit} f' "$handoff" | wc -c | tr -d ' ')"
[ "$bounded_reads_bytes" -le 1005 ] && ok "(G-17b) ## Bounded reads <= 1005 B" \
  || bad "(G-17b) ## Bounded reads <= 1005 B" "actual $bounded_reads_bytes"

plan_slice_block="$(awk '/^## Plan slice$/{f=1} f&&/^## /&&!/^## Plan slice$/{exit} f' "$handoff")"
[ -n "$plan_slice_block" ] && ok "(G-17c) ## Plan slice block found" \
  || bad "(G-17c) ## Plan slice block found" "empty extraction — heading text or boundary drifted"

printf '%s' "$plan_slice_block" | grep -qF -- 'SLICE' \
  && ok "(G-17d) ## Plan slice block contains SLICE" \
  || bad "(G-17d) ## Plan slice block contains SLICE" "token not found in extracted block"

printf '%s' "$plan_slice_block" | grep -qF -- 'Status: blocked' \
  && ok "(G-17e) ## Plan slice block contains Status: blocked" \
  || bad "(G-17e) ## Plan slice block contains Status: blocked" "token not found in extracted block"

# --- G-18: ac-verification.md checklist item 1, extracted --------------------------
# Bound to the ## Procedure section FIRST — ac-verification.md has a second, unrelated
# numbered-list item 1 inside ## Defect regression-evidence contract further down the file.
# Without this bound, a renumbering perturbation on the Procedure's item 1 does not produce an
# empty extraction (the falsifiable case) — it silently falls through to the wrong section's
# item 1 instead, which still looks non-empty and masks the regression.
proc_section="$(awk '/^## Procedure$/{f=1;next} f&&/^## /{exit} f' "$ac")"
item1="$(printf '%s\n' "$proc_section" | awk '/^1\. /{f=1} f&&/^2\. /{exit} f')"
[ -n "$item1" ] && ok "(G-18a) checklist item 1 found" \
  || bad "(G-18a) checklist item 1 found" "empty extraction — item numbering or boundary drifted"

printf '%s' "$item1" | grep -qF -- 'checklist`-mode slice' \
  && ok "(G-18b) item 1 sources the checklist-mode slice" \
  || bad "(G-18b) item 1 sources the checklist-mode slice" "'checklist\`-mode slice' token not found in item 1 — plain 'checklist' also appears in the unrelated trailing parenthetical, so it is not falsifiable on its own"

printf '%s' "$item1" | grep -qF -- 'GRAMMAR=unmatched' \
  && ok "(G-18c) item 1 falls back to whole plan on GRAMMAR=unmatched" \
  || bad "(G-18c) item 1 falls back to whole plan on GRAMMAR=unmatched" "'GRAMMAR=unmatched' token not found in item 1"

exit "$fail"
