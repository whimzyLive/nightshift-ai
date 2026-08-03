#!/usr/bin/env bash
# loop-decide.test.sh — NA-93. The exhaustive equivalence gate for loop-decide.sh.
#
# AUTHOR-RUN AND CI-WIRED:
#   bash plugins/sdlc/scripts/__tests__/loop-decide.test.sh
# Exit 0 = PASS, exit 1 = FAIL.
#
# H-Gate-2 is the ONE gate on this epic that escapes NA-88 D11: the golden it compares against
# was extracted from the PRE-change tables, in an earlier phase, by a DIFFERENT agent, from text
# this script's author did not write. Assertion (g) proves that provenance mechanically.
#
# WHAT A GREEN RUN DOES NOT PROVE: rules 1, 5, 6 and 7 have ZERO production evidence — 186 real
# loop-status: snapshots carry only 9 distinct tuples. Enumeration proves the port matches the
# table. It does NOT prove the table was right. Rule 6 (failing checks -> halt) and rule 7
# (catch-all -> halt) are the two that would matter most if wrong, and both are unexercised.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$here/../../../.."
decide="$root/plugins/sdlc/scripts/loop-decide.sh"
golden="$root/tools/sdlc-analyser/__tests__/fixtures/loop-decision-golden.json"
fail=0

ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n     %s\n' "$1" "$2"; fail=1; }

field() { printf '%s\n' "$1" | grep -o "^${2}=[^[:space:]]*" | sed "s/^${2}=//" | sed "s/^'//;s/'\$//"; }
nlines() { printf '%s' "$1" | grep -c '^' ; }

# --- (a)-(c) H-Smoke-2: exit 0, exactly 9 lines, <= 600 B on 4 input classes ---------
# IMPORTANT: run_case must NEVER be invoked via `$(...)` — its ok()/bad() diagnostics print to
# real stdout; capturing the whole function's stdout in a variable would swallow those lines
# into the "captured invocation output" and corrupt every downstream field() extraction. It
# hands the real invocation's own stdout back via the global RC_OUT instead.
run_case() { # <label> <args...>
  local label="$1"; shift
  local ec n b
  RC_OUT="$(bash "$decide" "$@" 2>/dev/null)"; ec=$?
  n="$(nlines "$RC_OUT")"
  b="$(printf '%s' "$RC_OUT" | wc -c | tr -d ' ')"
  [ "$ec" -eq 0 ] && ok "(a) $label exits 0" || bad "(a) $label exits 0" "got exit=$ec"
  [ "$n" -eq 9 ]  && ok "(b) $label emits exactly 9 lines" || bad "(b) $label emits exactly 9 lines" "got $n"
  [ "$b" -le 600 ] && ok "(c) $label <= 600 B" || bad "(c) $label <= 600 B" "got $b B"
}

run_case 'well-formed status line' --from-status 'loop-status: copilot-reviewed-head=1 copilot-changes-requested=0 copilot-pending=0 unresolved-copilot=0 checks-pending=0 checks-failing=0 checks-passing=1 copilot-reviewed-any=1'
wellformed_out="$RC_OUT"
run_case 'garbage line' --from-status 'garbage'
garbage_out="$RC_OUT"
run_case 'empty line' --from-status ''
empty_out="$RC_OUT"
run_case 'no arguments'
noargs_out="$RC_OUT"

# --- (d) F-10 fail safe: garbage / empty / no-args each -> RULE=unresolvable, DECISION=wait --
for pair in "garbage:$garbage_out" "empty:$empty_out" "noargs:$noargs_out"; do
  name="${pair%%:*}"; out="${pair#*:}"
  rule="$(field "$out" RULE)"; decision="$(field "$out" DECISION)"
  [ "$rule" = "unresolvable" ] && ok "(d) $name -> RULE=unresolvable" || bad "(d) $name -> RULE=unresolvable" "got RULE=$rule"
  [ "$decision" = "wait" ] && ok "(d) $name -> DECISION=wait" || bad "(d) $name -> DECISION=wait" "got DECISION=$decision"
  [ "$decision" != "clean" ] && ok "(d) $name -> DECISION != clean" || bad "(d) $name -> DECISION != clean" "got clean"
  [ "$decision" != "halt" ]  && ok "(d) $name -> DECISION != halt"  || bad "(d) $name -> DECISION != halt"  "got halt"
done

# a named field missing or non-numeric -> also unresolvable/wait
missingfield_out="$(bash "$decide" --from-status 'loop-status: copilot-reviewed-head=1 copilot-changes-requested=0 copilot-pending=0 unresolved-copilot=X checks-pending=0 checks-failing=0 checks-passing=1 copilot-reviewed-any=1' 2>/dev/null)"
mf_rule="$(field "$missingfield_out" RULE)"; mf_dec="$(field "$missingfield_out" DECISION)"
[ "$mf_rule" = "unresolvable" ] && ok "(d) non-numeric field -> RULE=unresolvable" || bad "(d) non-numeric field -> RULE=unresolvable" "got RULE=$mf_rule"
[ "$mf_dec" = "wait" ] && ok "(d) non-numeric field -> DECISION=wait" || bad "(d) non-numeric field -> DECISION=wait" "got DECISION=$mf_dec"

# --- (e) F-11: review-clean=- is legitimate, not a parse failure --------------------
cib_out="$(bash "$decide" --from-fields 'reviewed-head=0 review-clean=- unresolved=0 checks-pending=0 checks-failing=0' 2>/dev/null)"
cib_rule="$(field "$cib_out" RULE)"
[ "$cib_rule" = "CI-b" ] && ok "(e) review-clean=- with reviewed-head=0 -> RULE=CI-b, not unresolvable" \
  || bad "(e) review-clean=- -> RULE=CI-b" "got RULE=$cib_rule"

# --- (f) a resolved-but-unmatched copilot tuple still selects RULE=7, DECISION=halt (UNCHANGED)
# rh=9 is numeric (parses cleanly) but matches no rule's rh==0/rh==1 branch — the catch-all,
# not a fail-safe path.
rule7_out="$(bash "$decide" --from-status 'loop-status: copilot-reviewed-head=9 copilot-changes-requested=0 copilot-pending=0 unresolved-copilot=0 checks-pending=0 checks-failing=0 checks-passing=0 copilot-reviewed-any=0' 2>/dev/null)"
r7_rule="$(field "$rule7_out" RULE)"; r7_dec="$(field "$rule7_out" DECISION)"
[ "$r7_rule" = "7" ] && ok "(f) resolved-but-unmatched tuple -> RULE=7" || bad "(f) resolved-but-unmatched tuple -> RULE=7" "got RULE=$r7_rule"
[ "$r7_dec" = "halt" ] && ok "(f) resolved-but-unmatched tuple -> DECISION=halt" || bad "(f) resolved-but-unmatched tuple -> DECISION=halt" "got DECISION=$r7_dec"

# --- (g) golden provenance (F-17, amendment A3) -------------------------------------
sha="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['sourceSha'])" "$golden")"
lb="$(git -C "$root" show "$sha:plugins/sdlc/commands/loop.md" | wc -c | tr -d ' ')"
mb="$(git -C "$root" show "$sha:plugins/sdlc/refs/loop-modes.md" | wc -c | tr -d ' ')"
[ "$lb" -eq 17544 ] && [ "$mb" -eq 18851 ] && ok "(g) golden extracted from the PRE-change tables ($sha)" \
  || bad "(g) golden provenance" "at $sha loop.md=$lb (want 17544) loop-modes.md=$mb (want 18851) — the golden was regenerated AFTER the rewrite; it now compares H to itself"

# --- (h) H-Gate-2: all 1,458 cases through the REAL script, vs the golden -----------
gate2_out="$(python3 - "$decide" "$golden" <<'PY'
import json, subprocess, sys

decide, golden_path = sys.argv[1], sys.argv[2]
golden = json.load(open(golden_path))
cases = golden["cases"]
mismatches = []
evaluated = 0

for c in cases:
    f = c["fields"]
    if c["path"] == "copilot":
        line = ("loop-status: copilot-reviewed-head=%d copilot-changes-requested=%d "
                "copilot-pending=%d unresolved-copilot=%d checks-pending=%d "
                "checks-failing=%d checks-passing=%d copilot-reviewed-any=%d") % (
            f["copilot-reviewed-head"], f["copilot-changes-requested"], f["copilot-pending"],
            f["unresolved-copilot"], f["checks-pending"], f["checks-failing"],
            f["checks-passing"], f["copilot-reviewed-any"])
        args = [decide, "--from-status", line]
    else:
        line = "reviewed-head=%d review-clean=%s unresolved=%d checks-pending=%d checks-failing=%d" % (
            f["reviewed-head"], f["review-clean"], f["unresolved"], f["checks-pending"], f["checks-failing"])
        args = [decide, "--from-fields", line]

    out = subprocess.run(["bash"] + args, capture_output=True, text=True).stdout
    actual_rule = None
    actual_decision = None
    for l in out.splitlines():
        if l.startswith("RULE="):
            actual_rule = l[len("RULE="):].strip("'")
        elif l.startswith("DECISION="):
            actual_decision = l[len("DECISION="):].strip("'")
    evaluated += 1
    # Compare BOTH fields: RULE alone would miss a perturbation that keeps the rule id but
    # remaps its DECISION token (F-16 names exactly this: map rule 3 to a different token).
    if actual_rule != c["rule"] or actual_decision != c["decision"]:
        mismatches.append({"case": f, "path": c["path"], "goldenRule": c["rule"], "actualRule": actual_rule,
                            "goldenDecision": c["decision"], "actualDecision": actual_decision})

print(json.dumps({"evaluated": evaluated, "mismatches": mismatches[:10], "mismatchCount": len(mismatches)}))
PY
)"
h_evaluated="$(printf '%s' "$gate2_out" | python3 -c "import json,sys;print(json.load(sys.stdin)['evaluated'])")"
h_mismatch_count="$(printf '%s' "$gate2_out" | python3 -c "import json,sys;print(json.load(sys.stdin)['mismatchCount'])")"
echo "H-Gate-2: evaluated=$h_evaluated mismatches=$h_mismatch_count"
[ "$h_evaluated" -eq 1458 ] && ok "(h) H-Gate-2 evaluated exactly 1458 cases" \
  || bad "(h) H-Gate-2 evaluated exactly 1458 cases" "got $h_evaluated — the golden silently shrank"
[ "$h_mismatch_count" -eq 0 ] && ok "(h) H-Gate-2 mismatches empty" \
  || bad "(h) H-Gate-2 mismatches empty" "$(printf '%s' "$gate2_out" | python3 -c "import json,sys;print(json.load(sys.stdin)['mismatches'])")"

# --- (i) H-Gate-2b: single-decide() convergence over the 9 real snapshots ------------
# tuples are (rh, cr, cp, un, pend, fail, pass, ra) -> golden rule
snapshots='
0 0 0 0 0 0 0 0 2a
0 0 0 0 0 0 0 1 2b
0 0 0 1 0 0 0 1 2b
0 0 0 2 0 0 0 1 2b
1 0 0 0 0 0 0 1 4
1 0 0 1 0 0 0 1 3
1 0 0 2 0 0 0 1 3
1 0 0 3 0 0 0 1 3
1 0 0 4 0 0 0 1 3
'
shim="$(mktemp -d)"
trap 'rm -rf "$shim"' EXIT
cat > "$shim/gh" <<'EOF'
#!/usr/bin/env bash
echo "deadbeefcafefeed00000000000000000000000"
EOF
chmod +x "$shim/gh"

# NOTE: the loop variable is named `cfail` (never `fail`) — this file's own PASS/FAIL
# accumulator is `fail`, and shadowing it inside this loop silently corrupts the final
# `exit "$fail"` below. Naming collision, not logic — keep them visibly distinct.
while read -r rh cr cp un pend cfail pass ra rule; do
  [ -z "${rh:-}" ] && continue
  line="loop-status: copilot-reviewed-head=$rh copilot-changes-requested=$cr copilot-pending=$cp unresolved-copilot=$un checks-pending=$pend checks-failing=$cfail checks-passing=$pass copilot-reviewed-any=$ra"
  cat > "$shim/pr-loop-status.sh" <<EOF2
#!/usr/bin/env bash
echo "$line"
EOF2
  chmod +x "$shim/pr-loop-status.sh"
  probe_block="$(SDLC_LOOP_PROBE_DIR="$shim" SDLC_LOOP_GH="$shim/gh" bash "$decide" 999 copilot "$shim" 2>/dev/null | grep -v '^HEAD=')"
  inject_block="$(bash "$decide" --from-status "$line" 2>/dev/null | grep -v '^HEAD=')"
  if [ "$probe_block" = "$inject_block" ]; then
    ok "(i) H-Gate-2b convergence for rule $rule tuple ($rh,$cr,$cp,$un,$pend,$cfail,$pass,$ra)"
  else
    bad "(i) H-Gate-2b convergence for rule $rule tuple ($rh,$cr,$cp,$un,$pend,$cfail,$pass,$ra)" \
      "probe:[$probe_block] != inject:[$inject_block]"
  fi
done <<<"$snapshots"

# --- (j) C1 regression: a failing in-session unresolved-comments probe must resolve to
# RULE=unresolvable / DECISION=wait, NEVER DECISION=clean. Drives the in-session probe path
# end-to-end (probe_insession) — no prior case in this file exercises it at all, let alone a
# failing one, which is exactly how a `pr-unresolved-comments.sh` auth/network failure could
# have been silently swallowed into a false "clean" (auto-merge under --on-clean).
isdir="$(mktemp -d)"
trap 'rm -rf "$shim" "$isdir"' EXIT
cat > "$isdir/gh" <<'EOF'
#!/usr/bin/env bash
echo "deadbeefcafefeed00000000000000000000000"
EOF
chmod +x "$isdir/gh"
cat > "$isdir/pr-loop-status.sh" <<'EOF'
#!/usr/bin/env bash
echo "loop-status: checks-pending=0 checks-failing=0"
EOF
chmod +x "$isdir/pr-loop-status.sh"
cat > "$isdir/pr-unresolved-comments.sh" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$isdir/pr-unresolved-comments.sh"
j_out="$(SDLC_LOOP_PROBE_DIR="$isdir" SDLC_LOOP_GH="$isdir/gh" bash "$decide" 999 in-session "$isdir" 2>/dev/null)"
j_rule="$(field "$j_out" RULE)"; j_dec="$(field "$j_out" DECISION)"
[ "$j_rule" = "unresolvable" ] && ok "(j) failing in-session unresolved-comments probe -> RULE=unresolvable" \
  || bad "(j) failing in-session unresolved-comments probe -> RULE=unresolvable" "got RULE=$j_rule"
[ "$j_dec" = "wait" ] && ok "(j) failing in-session unresolved-comments probe -> DECISION=wait" \
  || bad "(j) failing in-session unresolved-comments probe -> DECISION=wait" "got DECISION=$j_dec"
[ "$j_dec" != "clean" ] && ok "(j) failing in-session unresolved-comments probe -> DECISION != clean" \
  || bad "(j) failing in-session unresolved-comments probe -> DECISION != clean" "got clean (C1 regression)"
# BLOCKED_BY is multi-word — field() only extracts up to the first whitespace, so check the
# raw block for the substring instead of round-tripping it through field().
case "$j_out" in
  *'pr-unresolved-comments.sh failed'*) ok "(j) BLOCKED_BY names the failing probe" ;;
  *) bad "(j) BLOCKED_BY names the failing probe" "got: $j_out" ;;
esac

exit "$fail"
