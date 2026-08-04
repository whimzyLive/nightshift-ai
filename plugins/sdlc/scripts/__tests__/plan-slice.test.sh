#!/usr/bin/env bash
# plan-slice.test.sh — NA-81 Phase 2. Gates G-1 through G-13 for plan-slice.sh: the eval-safe
# five-key contract, the fence-aware phase/checklist extraction, every fallback path, the
# $WORKTREE resolution (the /auto bug), the eval-quoting adversarial proof, and the real-corpus
# replay (the load-bearing gate — G-10 exists so this script cannot repeat docs-sync-gate.sh's
# NA-92 lesson of passing every fixture while being inert against the real manifest).
#
# AUTHOR-RUN AND CI-WIRED:
#   bash plugins/sdlc/scripts/__tests__/plan-slice.test.sh
# Exit 0 = PASS, exit 1 = FAIL.
#
# Every invocation of plan-slice.sh below is a REAL invocation whose stdout is captured and
# parsed or eval'd — no assertion in this file greps plan-slice.sh's own source.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$here/../../../.."
script="$root/plugins/sdlc/scripts/plan-slice.sh"
fixdir="$here/fixtures/plan-slice"
plans="$fixdir/plans"
goldens="$fixdir/goldens"
exp="$fixdir/corpus-expectation.tsv"
fail=0

ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n     %s\n' "$1" "$2"; fail=1; }

run() { bash "$script" "$@"; }

# --- G-1: existence, non-empty, executable -----------------------------------------
[ -s "$script" ] && ok "(G-1) plan-slice.sh exists and is non-empty" \
  || bad "(G-1) plan-slice.sh exists and is non-empty" "missing or empty: $script"
[ -x "$script" ] && ok "(G-1) plan-slice.sh is executable" \
  || bad "(G-1) plan-slice.sh is executable" "not +x: $script"

# --- G-2: one key per assertion, parsed from a REAL invocation's raw stdout --------
raw="$(run "$plans/bracket.md" phase platform-engineer)"
for k in MODE SLICE TASKS PHASES GRAMMAR; do
  v="$(printf '%s\n' "$raw" | sed -n "s/^$k=//p")"
  [ -n "$v" ] && ok "(G-2 $k) key present and non-empty in real stdout" \
    || bad "(G-2 $k) key present and non-empty in real stdout" "key absent or empty"
done
n_lines="$(printf '%s\n' "$raw" | grep -c .)"
[ "$n_lines" -eq 5 ] && ok "(G-2) stdout is exactly 5 lines" \
  || bad "(G-2) stdout is exactly 5 lines" "actual $n_lines"

# --- G-3: phase slice byte-equal to its sha-pinned golden, exact first/last line ---
out="$(run "$plans/bracket.md" phase platform-engineer)"
eval "$out"
cmp -s "$SLICE" "$goldens/bracket.platform-engineer.slice" \
  && ok "(G-3) bracket/platform-engineer slice byte-equal to golden" \
  || bad "(G-3) bracket/platform-engineer slice byte-equal to golden" "cmp differs: $SLICE vs golden"
first_line="$(head -1 "$SLICE")"
[ "$first_line" = '## Phase 1 — Backend [platform-engineer]' ] \
  && ok "(G-3) first line is the exact heading string" \
  || bad "(G-3) first line is the exact heading string" "actual: $first_line"
# SECTION_END is the NEXT ^##[^#] line — the source's own blank-line separator before that
# heading is still inside this section, so the slice legitimately ends "...backend\n\n" (both
# plan-slice.sh and the independent golden agree). "Last line" therefore means the last
# NON-BLANK line, not tail -1's literal (blank) final line.
last_line="$(awk 'NF{l=$0} END{print l}' "$SLICE")"
[ "$last_line" = '- [x] Task three for backend' ] \
  && ok "(G-3) last (non-blank) line is the exact expected final line" \
  || bad "(G-3) last (non-blank) line is the exact expected final line" "actual: $last_line"
unset MODE SLICE TASKS PHASES GRAMMAR

# --- G-4: two-phases-one-agent — ordered heading list, exact 2-element match ------
out="$(run "$plans/two-phase.md" phase ai-enablement-engineer)"
eval "$out"
headings="$(grep -n '^## ' "$SLICE" | cut -d: -f2-)"
expected_headings='## Phase 1 — First slice `[ai-enablement-engineer]`
## Phase 3 — Second slice `[ai-enablement-engineer]`'
[ "$headings" = "$expected_headings" ] \
  && ok "(G-4) two-phase slice carries both headings, in order" \
  || bad "(G-4) two-phase slice carries both headings, in order" "actual:
$headings"
unset MODE SLICE TASKS PHASES GRAMMAR

# --- G-5: fenced-fake-heading fixture — PHASES/TASKS exclude the fenced content ----
out="$(run "$plans/fenced.md" phase web-engineer)"
eval "$out"
[ "$PHASES" = "1" ] && ok "(G-5) PHASES excludes the fenced fake heading (== 1)" \
  || bad "(G-5) PHASES == 1 (real heading only)" "actual $PHASES"
[ "$TASKS" = "2" ] && ok "(G-5) TASKS excludes the fenced '- [ ] fake' line (== 2)" \
  || bad "(G-5) TASKS == 2 (real task lines only)" "actual $TASKS"
# Note: the fenced block's literal text (including the fake heading and fake task line) IS
# expected to appear verbatim inside the slice — it is real quoted content of the one genuine
# phase section, preserved exactly as the source file wrote it. What must NOT happen is that
# fake heading incrementing PHASES or that fake task line incrementing TASKS — already asserted
# above. Asserting "fake" is absent from the slice would be a false requirement.
unset MODE SLICE TASKS PHASES GRAMMAR

# --- G-6: zero-phase fixture — the fallback, string-equal SLICE, TASKS > 0 --------
plan_arg="$plans/zero-phase.md"
out="$(run "$plan_arg" phase platform-engineer)"; st=$?
eval "$out"
[ "$st" -eq 0 ] && ok "(G-6) zero-phase fixture exits 0" || bad "(G-6) exit == 0" "actual $st"
[ "$GRAMMAR" = "unmatched" ] && ok "(G-6) GRAMMAR == unmatched" \
  || bad "(G-6) GRAMMAR == unmatched" "actual $GRAMMAR"
[ "$SLICE" = "$plan_arg" ] && ok "(G-6) SLICE string-equals the plan path passed in" \
  || bad "(G-6) SLICE string-equals the plan path passed in" "actual '$SLICE' expected '$plan_arg'"
[ "${TASKS:-0}" -gt 0 ] && ok "(G-6) TASKS > 0 (whole-doc fallback count)" \
  || bad "(G-6) TASKS > 0" "actual $TASKS"
unset MODE SLICE TASKS PHASES GRAMMAR

# --- G-7: phase-bearing fixture, agent absent — the fallback again ----------------
plan_arg="$plans/absent-agent.md"
out="$(run "$plan_arg" phase mobile-engineer)"
eval "$out"
[ "$SLICE" = "$plan_arg" ] && ok "(G-7) SLICE string-equals the plan path (agent absent)" \
  || bad "(G-7) SLICE string-equals the plan path" "actual '$SLICE' expected '$plan_arg'"
[ "$GRAMMAR" = "matched" ] && ok "(G-7) GRAMMAR == matched (doc HAS phase headings)" \
  || bad "(G-7) GRAMMAR == matched" "actual $GRAMMAR"
[ "${PHASES:-0}" -gt 0 ] && ok "(G-7) PHASES > 0" || bad "(G-7) PHASES > 0" "actual $PHASES"
unset MODE SLICE TASKS PHASES GRAMMAR

# --- G-8: missing plan / bad-mode / bad-args — exit 2, no SLICE= key ever --------
raw="$(run /nope/nope.md phase web-engineer)"; st=$?
[ "$st" -eq 2 ] && ok "(G-8 plan-not-found) exit == 2" || bad "(G-8 plan-not-found) exit == 2" "actual $st"
err="$(printf '%s\n' "$raw" | sed -n 's/^ERROR=//p')"
[ "$err" = "plan-not-found" ] && ok "(G-8 plan-not-found) ERROR == plan-not-found" \
  || bad "(G-8 plan-not-found) ERROR == plan-not-found" "actual '$err'"
slice_keys="$(printf '%s\n' "$raw" | grep -c '^SLICE=')"
[ "$slice_keys" -eq 0 ] && ok "(G-8 plan-not-found) no SLICE= key on the error path" \
  || bad "(G-8 plan-not-found) no SLICE= key on the error path" "found $slice_keys"

raw="$(run "$plans/bracket.md" bogus)"; st=$?
[ "$st" -eq 2 ] && ok "(G-8 bad-mode) exit == 2" || bad "(G-8 bad-mode) exit == 2" "actual $st"
err="$(printf '%s\n' "$raw" | sed -n 's/^ERROR=//p')"
[ "$err" = "bad-mode" ] && ok "(G-8 bad-mode) ERROR == bad-mode" \
  || bad "(G-8 bad-mode) ERROR == bad-mode" "actual '$err'"
slice_keys="$(printf '%s\n' "$raw" | grep -c '^SLICE=')"
[ "$slice_keys" -eq 0 ] && ok "(G-8 bad-mode) no SLICE= key on the error path" \
  || bad "(G-8 bad-mode) no SLICE= key on the error path" "found $slice_keys"

raw="$(run)"; st=$?
[ "$st" -eq 2 ] && ok "(G-8 bad-args) exit == 2" || bad "(G-8 bad-args) exit == 2" "actual $st"
err="$(printf '%s\n' "$raw" | sed -n 's/^ERROR=//p')"
[ "$err" = "bad-args" ] && ok "(G-8 bad-args) ERROR == bad-args" \
  || bad "(G-8 bad-args) ERROR == bad-args" "actual '$err'"
slice_keys="$(printf '%s\n' "$raw" | grep -c '^SLICE=')"
[ "$slice_keys" -eq 0 ] && ok "(G-8 bad-args) no SLICE= key on the error path" \
  || bad "(G-8 bad-args) no SLICE= key on the error path" "found $slice_keys"

# --- G-9: checklist mode — integer-equal count, line-by-line compare, PHASES == 0 -
out="$(run "$plans/bracket.md" checklist)"
eval "$out"
golden_count="$(grep -c . "$goldens/bracket.checklist")"
[ "$TASKS" = "$golden_count" ] && ok "(G-9) TASKS integer-equals the golden count ($golden_count)" \
  || bad "(G-9) TASKS integer-equals the golden count" "actual $TASKS expected $golden_count"
if diff -u "$SLICE" "$goldens/bracket.checklist" > /dev/null 2>&1; then
  ok "(G-9) emitted checklist lines compare line-by-line to the golden"
else
  bad "(G-9) emitted checklist lines compare line-by-line to the golden" "diff found"
fi
[ "$PHASES" = "0" ] && ok "(G-9) PHASES == 0 (forced, checklist mode)" \
  || bad "(G-9) PHASES == 0" "actual $PHASES"
unset MODE SLICE TASKS PHASES GRAMMAR

# --- G-10: the real-corpus replay — the load-bearing gate -------------------------
row_count=0
mismatch=0
while IFS=$'\t' read -r name grammar phases tasks; do
  case "$name" in '#'*|'') continue ;; esac
  row_count=$((row_count + 1))
  out="$(cd "$root" && bash plugins/sdlc/scripts/plan-slice.sh "docs/superpowers/plans/$name" phase ai-enablement-engineer)"
  st=$?
  eval "$out"
  if [ "$st" -ne 0 ] || [ -z "${SLICE:-}" ] || [ ! -r "$SLICE" ] \
     || [ "$GRAMMAR" != "$grammar" ] || [ "$PHASES" != "$phases" ] || [ "$TASKS" != "$tasks" ]; then
    mismatch=$((mismatch + 1))
    printf '     row mismatch: %s expected(grammar=%s phases=%s tasks=%s) actual(exit=%s grammar=%s phases=%s tasks=%s)\n' \
      "$name" "$grammar" "$phases" "$tasks" "$st" "${GRAMMAR:-}" "${PHASES:-}" "${TASKS:-}"
  fi
  unset MODE SLICE TASKS PHASES GRAMMAR
done < "$exp"
[ "$mismatch" -eq 0 ] && ok "(G-10) every corpus row matches exit/SLICE/GRAMMAR/PHASES/TASKS ($row_count rows)" \
  || bad "(G-10) every corpus row matches" "$mismatch of $row_count rows mismatched"

exp_files="$(sed -n 's/^# files: *\([0-9]*\).*/\1/p' "$exp")"
exp_matched="$(sed -n 's/.*# matched: *\([0-9]*\).*/\1/p' "$exp")"
exp_unmatched="$(sed -n 's/.*# unmatched: *\([0-9]*\).*/\1/p' "$exp")"
glob_count="$(cd "$root" && find docs/superpowers/plans -maxdepth 1 -name '*.md' -type f | wc -l | tr -d ' ')"
[ "$row_count" -eq "$exp_files" ] && [ "$row_count" -eq "$glob_count" ] \
  && ok "(G-10) row count ($row_count) == header's # files ($exp_files) == the non-recursive glob ($glob_count)" \
  || bad "(G-10) row count == # files == glob count" "rows=$row_count files=$exp_files glob=$glob_count"

actual_matched="$(awk -F'\t' '$1!~/^#/{if($2=="matched")c++}END{print c+0}' "$exp")"
actual_unmatched="$(awk -F'\t' '$1!~/^#/{if($2=="unmatched")c++}END{print c+0}' "$exp")"
[ "$actual_matched" -eq "$exp_matched" ] && [ "$actual_unmatched" -eq "$exp_unmatched" ] \
  && ok "(G-10) matched/unmatched counts ($actual_matched/$actual_unmatched) == header" \
  || bad "(G-10) matched/unmatched counts == header" "matched=$actual_matched (hdr $exp_matched) unmatched=$actual_unmatched (hdr $exp_unmatched)"

# --- G-11: delimiter coverage — five forms, each on a fixture carrying only it -----
out="$(run "$plans/bracket.md" phase platform-engineer)"; eval "$out"
[ "${PHASES:-0}" -ge 1 ] && ok "(G-11 bracket [x]) PHASES >= 1" || bad "(G-11 bracket [x]) PHASES >= 1" "actual $PHASES"
unset MODE SLICE TASKS PHASES GRAMMAR

out="$(run "$plans/backtick.md" phase platform-engineer)"; eval "$out"
[ "${PHASES:-0}" -ge 1 ] && ok "(G-11 backtick \`x\`) PHASES >= 1" || bad "(G-11 backtick \`x\`) PHASES >= 1" "actual $PHASES"
unset MODE SLICE TASKS PHASES GRAMMAR

out="$(run "$plans/backtick.md" phase ai-enablement-engineer)"; eval "$out"
[ "${PHASES:-0}" -ge 1 ] && ok "(G-11 ordinal-less) PHASES >= 1" || bad "(G-11 ordinal-less) PHASES >= 1" "actual $PHASES"
unset MODE SLICE TASKS PHASES GRAMMAR

out="$(run "$plans/absent-agent.md" phase web-engineer)"; eval "$out"
[ "${PHASES:-0}" -ge 1 ] && ok "(G-11 bare parens (x)) PHASES >= 1" || bad "(G-11 bare parens (x)) PHASES >= 1" "actual $PHASES"
unset MODE SLICE TASKS PHASES GRAMMAR

out="$(run "$plans/two-phase.md" phase ai-enablement-engineer)"; eval "$out"
[ "${PHASES:-0}" -ge 1 ] && ok "(G-11 backticked brackets \`[x]\`) PHASES >= 1" \
  || bad "(G-11 backticked brackets \`[x]\`) PHASES >= 1" "actual $PHASES"
unset MODE SLICE TASKS PHASES GRAMMAR

# --- G-12: $WORKTREE resolution — the /auto Workflow-A bug ------------------------
scratch="$(mktemp -d)"
mkdir -p "$scratch/wt/docs/superpowers/plans" "$scratch/cwd"
cp "$plans/bracket.md" "$scratch/wt/docs/superpowers/plans/X.md"
direct_out="$(run "$scratch/wt/docs/superpowers/plans/X.md" phase platform-engineer)"
eval "$direct_out"
direct_slice="$SLICE"
unset MODE SLICE TASKS PHASES GRAMMAR
wt_out="$(cd "$scratch/cwd" && WORKTREE="$scratch/wt" bash "$script" docs/superpowers/plans/X.md phase platform-engineer)"
wt_st=$?
eval "$wt_out"
[ "$wt_st" -eq 0 ] && ok "(G-12) \$WORKTREE resolution exits 0 from a CWD with no direct copy" \
  || bad "(G-12) exit == 0" "actual $wt_st"
[ "$GRAMMAR" = "matched" ] && ok "(G-12) GRAMMAR == matched via \$WORKTREE resolution" \
  || bad "(G-12) GRAMMAR == matched" "actual $GRAMMAR"
if cmp -s "$SLICE" "$direct_slice"; then
  ok "(G-12) \$WORKTREE-resolved slice is byte-equal to the direct-path slice"
else
  bad "(G-12) \$WORKTREE-resolved slice byte-equal to direct-path slice" "cmp differs"
fi
unset MODE SLICE TASKS PHASES GRAMMAR
rm -rf "$scratch"

# --- G-13: eval safety, adversarial — a space AND an embedded single quote --------
# Uses the zero-phase (fallback) fixture deliberately: on the fallback path SLICE is the
# resolved PLAN PATH ITSELF (unchanged), so this is the one case where the adversarial
# characters actually flow into the eval'd value. A "matched" fixture would return an
# auto-generated tmp-file SLICE containing none of the adversarial characters, proving
# nothing about shq()'s quoting.
scratch2="$(mktemp -d)"
adv_plan="$scratch2/plan with space and ' quote.md"
cp "$plans/zero-phase.md" "$adv_plan"
canary="$scratch2/CANARY_SHOULD_NOT_EXIST"
adv_out="$(run "$adv_plan" phase platform-engineer)"
(
  eval "$adv_out"
  if [ -n "${SLICE:-}" ] && [ "$SLICE" = "$adv_plan" ]; then
    ok_inner=1
  else
    ok_inner=0
  fi
  printf '%s\n' "$ok_inner" > "$scratch2/inner-ok"
)
inner_ok="$(cat "$scratch2/inner-ok" 2>/dev/null || echo 0)"
[ "$inner_ok" = "1" ] && ok "(G-13) SLICE survives eval byte-equal to the adversarial path (space + embedded quote)" \
  || bad "(G-13) SLICE survives eval byte-equal to the adversarial path" "post-eval SLICE did not match '$adv_plan'"
[ ! -e "$canary" ] && ok "(G-13) no stray file/command side effect from the adversarial path" \
  || bad "(G-13) no stray side effect" "$canary was created"
rm -rf "$scratch2"

# --- G-1 provenance: corpus-expectation.tsv's sourceSha resolves NA-93.md's bytes --
sha="$(sed -n 's/^# sourceSha: //p' "$exp" | head -1)"
recorded="$(sed -n 's/.*NA-93.md=\([0-9]*\).*/\1/p' "$exp" | head -1)"
actual_bytes="$(cd "$root" && git show "$sha:docs/superpowers/plans/NA-93.md" 2>/dev/null | wc -c | tr -d ' ')"
[ -n "$sha" ] && [ -n "$recorded" ] && [ "$actual_bytes" = "$recorded" ] \
  && ok "(provenance) git show \$sha:NA-93.md bytes ($actual_bytes) == recorded sourceBytes" \
  || bad "(provenance) recorded sourceBytes matches git show at sourceSha" "sha='$sha' recorded='$recorded' actual='$actual_bytes'"

exit "$fail"
