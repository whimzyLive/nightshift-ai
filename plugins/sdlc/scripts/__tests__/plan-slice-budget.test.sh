#!/usr/bin/env bash
# plan-slice-budget.test.sh — NA-81 Phase 1. Gates G-14 (the three playbook/command byte caps,
# unrelated to plan-slice.sh, which does not exist yet when this file first lands) and G-15
# (site C: the reviewer now receives a PATH, never pasted content).
#
# AUTHOR-RUN AND CI-WIRED:
#   bash plugins/sdlc/scripts/__tests__/plan-slice-budget.test.sh
# Exit 0 = PASS, exit 1 = FAIL.
#
# Runnable and green BEFORE plan-slice.sh exists (Phase 2) — this file asserts nothing about the
# slicer. It is deliberately committed on its own, ahead of Phase 2, so Site C's win is not held
# hostage to slicer trouble.
#
# G-15 note on "the extracted block": the plan's falsifiability register (G-15) and Task 1.2 Step 3
# both describe extracting the `PLAN_OR_REQUIREMENTS` bullet block via awk from the bullet line to
# "the next `^- ` line" and asserting, among other things, that the block's `wc -c` <= 211. Measured
# in this worktree, that awk-extracted block (bullet + its wrapped continuation lines, 131-136) is
# 539 B even BEFORE this story's edit — the 211 B cap can never have applied to it; 211 B is the
# byte ledger's cap on the specific edited hunk (`:132-133`, measured in Task 1.1). So this gate
# splits G-15 into: content assertions (a/b/c) on the awk-extracted block, and the byte cap (d) on
# the `132-133` line range Task 1.1 actually measured and budgeted. Re-verify this split before
# trusting a rewrite that renumbers the hunk.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$here/../../../.."
refs="$root/plugins/sdlc/refs"
qa="$refs/qa-engineer-playbook.md"
pe="$refs/principal-engineer-playbook.md"
loop_md="$root/plugins/sdlc/commands/loop.md"
loop_modes="$refs/loop-modes.md"
fail=0

ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n     %s\n' "$1" "$2"; fail=1; }

# --- G-14: the three byte assertions, literal constants ---------------------------
qb="$(wc -c < "$qa" | tr -d ' ')"
pb="$(wc -c < "$pe" | tr -d ' ')"
tot=$((qb + pb))
[ "$tot" -le 73704 ] && ok "(G-14a) combined playbooks $tot <= 73704" \
  || bad "(G-14a) combined playbooks <= 73704" "actual $tot (qa=$qb pe=$pb) — NEVER raise this constant"

lm="$(wc -c < "$loop_md" | tr -d ' ')"
[ "$lm" -eq 13445 ] && ok "(G-14b) commands/loop.md byte-unchanged at 13445" \
  || bad "(G-14b) commands/loop.md == 13445" "actual $lm"

lmo="$(wc -c < "$loop_modes" | tr -d ' ')"
[ "$lmo" -eq 13554 ] && ok "(G-14c) refs/loop-modes.md byte-unchanged at 13554" \
  || bad "(G-14c) refs/loop-modes.md == 13554" "actual $lmo"

# --- G-15: site C — the PLAN_OR_REQUIREMENTS block never pastes content again -----
block="$(awk '/^- `PLAN_OR_REQUIREMENTS`:/{f=1;print;next} f&&/^- /{exit} f' "$qa")"
[ -n "$block" ] && ok "(G-15a) PLAN_OR_REQUIREMENTS block found" \
  || bad "(G-15a) PLAN_OR_REQUIREMENTS block found" "empty extraction — boundary regex or heading text drifted"

printf '%s' "$block" | grep -qF -- 'docs/superpowers/plans/<STORY-KEY>.md' \
  && ok "(G-15b) block names docs/superpowers/plans/<STORY-KEY>.md" \
  || bad "(G-15b) block names the plan path" "path token not found in extracted block"

printf '%s' "$block" | grep -qF -- 'full content' \
  && bad "(G-15c) block no longer contains 'full content'" "still pastes content" \
  || ok "(G-15c) block no longer contains 'full content'"

hunk_b="$(awk 'NR==132 || NR==133' "$qa" | wc -c | tr -d ' ')"
[ "$hunk_b" -le 211 ] && ok "(G-15d) qa:132-133 hunk $hunk_b <= 211" \
  || bad "(G-15d) qa:132-133 hunk <= 211" "actual $hunk_b"

exit "$fail"
