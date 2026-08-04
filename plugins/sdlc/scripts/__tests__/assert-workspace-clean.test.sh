#!/usr/bin/env bash
# assert-workspace-clean.test.sh — contract + fail-closed coverage for assert-workspace-clean.sh
# (NA-86 A9).
#
# Self-runnable, no test harness/framework dependency:
#   bash plugins/sdlc/scripts/__tests__/assert-workspace-clean.test.sh
# Exit 0 = PASS (all cases), non-zero = FAIL (any case).
set -uo pipefail

here="${BASH_SOURCE[0]%/*}"; [ "$here" = "${BASH_SOURCE[0]}" ] && here="."
scripts_dir="$(cd "$here/.." && pwd)"
script="$scripts_dir/assert-workspace-clean.sh"

failures=0
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

fail() { echo "FAIL: $1" >&2; failures=$((failures + 1)); }
pass() { echo "PASS: $1"; }

get_field() { # $1=output $2=key
  printf '%s\n' "$1" | sed -n "s/^$2=//p" | head -1
}

# Every snapshot/assert call runs with its OWN ./.tmp (tmp-dir.sh scoped to cwd) and both
# session-key env vars unset, so a live SDLC_SESSION_KEY/CLAUDE_CODE_SESSION_ID in the runner's
# own environment never leaks a case's state file into a subdirectory this test never seeds.
run_in() { # $1=case-dir; remaining args passed to assert-workspace-clean.sh
  local dir="$1"; shift
  ( cd "$dir" && env -u SDLC_SESSION_KEY -u CLAUDE_CODE_SESSION_ID bash "$script" "$@" )
}

# Build a scratch git repo at $1 with one commit, returns nothing (repo left checked out).
make_repo() { # $1=repo-dir
  local repo="$1"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.email test@example.com
  git -C "$repo" config user.name test
  printf 'v1\n' > "$repo/file.txt"
  git -C "$repo" add file.txt
  git -C "$repo" commit -q -m init
}

# --- Case 1: clean snapshot -> clean assert -> OK/none -------------------------------
c1="$work/c1"; repo1="$c1/repo"; make_repo "$repo1"
snap_out="$(run_in "$c1" snapshot "$repo1")"; snap_rc=$?
state_file="$(get_field "$snap_out" PRIMARY_STATE_FILE)"
pre_dirty="$(get_field "$snap_out" PRIMARY_PRE_DIRTY)"
assert_out="$(run_in "$c1" assert "$repo1" "$state_file")"; assert_rc=$?
integrity="$(get_field "$assert_out" WORKSPACE_INTEGRITY)"
violation="$(get_field "$assert_out" WORKSPACE_VIOLATION)"
if [ "$snap_rc" -eq 0 ] && [ "$assert_rc" -eq 0 ] && [ "$pre_dirty" = "false" ] \
  && [ "$integrity" = "OK" ] && [ "$violation" = "none" ]; then
  pass "clean snapshot -> clean assert -> OK/none"
else
  fail "clean snapshot -> clean assert — got snap_rc=$snap_rc assert_rc=$assert_rc pre_dirty=$pre_dirty integrity=$integrity violation=$violation"
fi

# --- Case 2: pre-dirty snapshot that stays at the same dirt -> OK (a pass) -----------
c2="$work/c2"; repo2="$c2/repo"; make_repo "$repo2"
printf 'dirty\n' >> "$repo2/file.txt"
snap_out="$(run_in "$c2" snapshot "$repo2")"
pre_dirty="$(get_field "$snap_out" PRIMARY_PRE_DIRTY)"
state_file="$(get_field "$snap_out" PRIMARY_STATE_FILE)"
assert_out="$(run_in "$c2" assert "$repo2" "$state_file")"; assert_rc=$?
integrity="$(get_field "$assert_out" WORKSPACE_INTEGRITY)"
violation="$(get_field "$assert_out" WORKSPACE_VIOLATION)"
if [ "$pre_dirty" = "true" ] && [ "$assert_rc" -eq 0 ] && [ "$integrity" = "OK" ] && [ "$violation" = "none" ]; then
  pass "pre-dirty snapshot that stays at the same dirt -> OK/none"
else
  fail "pre-dirty-stays-dirty — got pre_dirty=$pre_dirty assert_rc=$assert_rc integrity=$integrity violation=$violation"
fi

# --- Case 3: HEAD moved -> VIOLATED/head-moved ----------------------------------------
c3="$work/c3"; repo3="$c3/repo"; make_repo "$repo3"
snap_out="$(run_in "$c3" snapshot "$repo3")"
state_file="$(get_field "$snap_out" PRIMARY_STATE_FILE)"
printf 'v2\n' > "$repo3/file.txt"
git -C "$repo3" commit -q -am "advance head"
assert_out="$(run_in "$c3" assert "$repo3" "$state_file")"; assert_rc=$?
integrity="$(get_field "$assert_out" WORKSPACE_INTEGRITY)"
violation="$(get_field "$assert_out" WORKSPACE_VIOLATION)"
if [ "$assert_rc" -eq 0 ] && [ "$integrity" = "VIOLATED" ] && [ "$violation" = "head-moved" ]; then
  pass "HEAD moved -> VIOLATED/head-moved"
else
  fail "HEAD moved — got assert_rc=$assert_rc integrity=$integrity violation=$violation"
fi

# --- Case 4: worktree changed (HEAD unchanged) -> VIOLATED/worktree-changed ----------
c4="$work/c4"; repo4="$c4/repo"; make_repo "$repo4"
snap_out="$(run_in "$c4" snapshot "$repo4")"
state_file="$(get_field "$snap_out" PRIMARY_STATE_FILE)"
printf 'uncommitted\n' >> "$repo4/file.txt"
assert_out="$(run_in "$c4" assert "$repo4" "$state_file")"; assert_rc=$?
integrity="$(get_field "$assert_out" WORKSPACE_INTEGRITY)"
violation="$(get_field "$assert_out" WORKSPACE_VIOLATION)"
if [ "$assert_rc" -eq 0 ] && [ "$integrity" = "VIOLATED" ] && [ "$violation" = "worktree-changed" ]; then
  pass "worktree changed -> VIOLATED/worktree-changed"
else
  fail "worktree changed — got assert_rc=$assert_rc integrity=$integrity violation=$violation"
fi

# --- Case 5: both HEAD moved and worktree changed -> VIOLATED/both -------------------
c5="$work/c5"; repo5="$c5/repo"; make_repo "$repo5"
snap_out="$(run_in "$c5" snapshot "$repo5")"
state_file="$(get_field "$snap_out" PRIMARY_STATE_FILE)"
printf 'v2\n' > "$repo5/file.txt"
git -C "$repo5" commit -q -am "advance head"
printf 'uncommitted\n' >> "$repo5/file.txt"
assert_out="$(run_in "$c5" assert "$repo5" "$state_file")"; assert_rc=$?
integrity="$(get_field "$assert_out" WORKSPACE_INTEGRITY)"
violation="$(get_field "$assert_out" WORKSPACE_VIOLATION)"
if [ "$assert_rc" -eq 0 ] && [ "$integrity" = "VIOLATED" ] && [ "$violation" = "both" ]; then
  pass "HEAD moved AND worktree changed -> VIOLATED/both"
else
  fail "both changed — got assert_rc=$assert_rc integrity=$integrity violation=$violation"
fi

# --- Case 6: missing state file -> hard error, non-zero exit, no WORKSPACE_INTEGRITY= line -----
c6="$work/c6"; repo6="$c6/repo"; make_repo "$repo6"
c6_out="$c6/stdout"; c6_err="$c6/stderr"
run_in "$c6" assert "$repo6" "$c6/does-not-exist" >"$c6_out" 2>"$c6_err"; assert_rc=$?
if [ "$assert_rc" -ne 0 ] && ! grep -q '^WORKSPACE_INTEGRITY=' "$c6_out"; then
  pass "missing state file -> hard error, non-zero exit, no WORKSPACE_INTEGRITY= line"
else
  fail "missing state file — got assert_rc=$assert_rc stdout='$(cat "$c6_out")'"
fi
[ -s "$c6_err" ] && pass "missing state file reports the failure on stderr" \
  || fail "missing state file stderr" "stderr empty"

# --- Case 7: every VERIFIABLE row exits 0 — re-confirm on a fresh OK pair and VIOLATED pair -----
c7="$work/c7"; repo7="$c7/repo"; make_repo "$repo7"
snap_out="$(run_in "$c7" snapshot "$repo7")"; snap_rc=$?
state_file="$(get_field "$snap_out" PRIMARY_STATE_FILE)"
run_in "$c7" assert "$repo7" "$state_file" >/dev/null; assert_ok_rc=$?
printf 'uncommitted\n' >> "$repo7/file.txt"
run_in "$c7" assert "$repo7" "$state_file" >/dev/null; assert_violated_rc=$?
if [ "$snap_rc" -eq 0 ] && [ "$assert_ok_rc" -eq 0 ] && [ "$assert_violated_rc" -eq 0 ]; then
  pass "every verifiable row exits 0 (decision lives in stdout, not exit code)"
else
  fail "row exit codes — got snap_rc=$snap_rc assert_ok_rc=$assert_ok_rc assert_violated_rc=$assert_violated_rc, want 0 0 0"
fi

# --- Case 7b: an EMPTY state file -> hard error, non-zero exit, no WORKSPACE_INTEGRITY= line ----
c7b="$work/c7b"; repo7b="$c7b/repo"; make_repo "$repo7b"
: > "$c7b/empty-state"
c7b_out="$c7b/stdout"; c7b_err="$c7b/stderr"
run_in "$c7b" assert "$repo7b" "$c7b/empty-state" >"$c7b_out" 2>"$c7b_err"; assert_rc=$?
if [ "$assert_rc" -ne 0 ] && ! grep -q '^WORKSPACE_INTEGRITY=' "$c7b_out"; then
  pass "an empty state file -> hard error, non-zero exit, no WORKSPACE_INTEGRITY= line"
else
  fail "empty state file — got assert_rc=$assert_rc stdout='$(cat "$c7b_out")'"
fi
[ -s "$c7b_err" ] && pass "empty state file reports the failure on stderr" \
  || fail "empty state file stderr" "stderr empty"

# --- Case 7c: a MALFORMED state file (line 1 is not a git oid) -> same --------------------------
c7c="$work/c7c"; repo7c="$c7c/repo"; make_repo "$repo7c"
printf 'not-an-oid\nsome status line\n' > "$c7c/malformed-state"
c7c_out="$c7c/stdout"; c7c_err="$c7c/stderr"
run_in "$c7c" assert "$repo7c" "$c7c/malformed-state" >"$c7c_out" 2>"$c7c_err"; assert_rc=$?
if [ "$assert_rc" -ne 0 ] && ! grep -q '^WORKSPACE_INTEGRITY=' "$c7c_out"; then
  pass "a malformed state file (line 1 not a git oid) -> hard error, no WORKSPACE_INTEGRITY= line"
else
  fail "malformed state file — got assert_rc=$assert_rc stdout='$(cat "$c7c_out")'"
fi
[ -s "$c7c_err" ] && pass "malformed state file reports the failure on stderr" \
  || fail "malformed state file stderr" "stderr empty"

# --- Case 7d: snapshot cannot write its state file -> hard error, no PRIMARY_STATE_FILE= line ---
c7d="$work/c7d"; repo7d="$c7d/repo"; make_repo "$repo7d"
mkdir -p "$c7d/.tmp"
chmod 500 "$c7d/.tmp"
c7d_out="$c7d/stdout"; c7d_err="$c7d/stderr"
run_in "$c7d" snapshot "$repo7d" >"$c7d_out" 2>"$c7d_err"; snap_rc=$?
chmod 700 "$c7d/.tmp"
if [ "$snap_rc" -ne 0 ] && ! grep -q '^PRIMARY_STATE_FILE=' "$c7d_out"; then
  pass "snapshot cannot create its state file -> hard error, no PRIMARY_STATE_FILE= line"
else
  fail "snapshot mktemp failure — got snap_rc=$snap_rc stdout='$(cat "$c7d_out")'"
fi
[ -s "$c7d_err" ] && pass "snapshot mktemp failure reports the failure on stderr" \
  || fail "snapshot mktemp failure stderr" "stderr empty"

# --- Case 7e: mktemp succeeds but the state-file write then fails -> hard error, no verdict line
c7e="$work/c7e"; repo7e="$c7e/repo"; make_repo "$repo7e"
mkdir -p "$c7e/.tmp"
chmod 755 "$c7e/.tmp"
c7e_out="$c7e/stdout"; c7e_err="$c7e/stderr"
( cd "$c7e" && umask 0600 && env -u SDLC_SESSION_KEY -u CLAUDE_CODE_SESSION_ID bash "$script" snapshot "$repo7e" ) >"$c7e_out" 2>"$c7e_err"
snap_rc=$?
if [ "$snap_rc" -ne 0 ] && ! grep -q '^PRIMARY_STATE_FILE=' "$c7e_out"; then
  pass "snapshot's write to its (successfully mktemp'd) state file failing -> hard error, no PRIMARY_STATE_FILE= line"
else
  fail "snapshot write failure — got snap_rc=$snap_rc stdout='$(cat "$c7e_out")'"
fi
[ -s "$c7e_err" ] && pass "snapshot write failure reports the failure on stderr" \
  || fail "snapshot write failure stderr" "stderr empty"

# --- Case 8: F7 regression — a failed git probe (non-git PRIMARY_ROOT) must be a hard error,
# never a silent empty PRIMARY_HEAD with exit 0 (which would turn the guard fail-open: any fault
# making `git -C "$PRIMARY_ROOT"` fail — a mis-substituted placeholder, a non-top-level path, a
# `safe.directory` refusal — must surface, not report a spurious clean snapshot).
c8="$work/c8"; nongit="$c8/not-a-repo"; mkdir -p "$nongit"
snap_out="$(run_in "$c8" snapshot "$nongit" 2>/dev/null)"; snap_rc=$?
head_field="$(get_field "$snap_out" PRIMARY_HEAD)"
if [ "$snap_rc" -ne 0 ] && [ -z "$head_field" ]; then
  pass "snapshot on a non-git PRIMARY_ROOT is a hard error (F7), not a silent empty PRIMARY_HEAD"
else
  fail "F7 regression — snapshot on non-git root got snap_rc=$snap_rc PRIMARY_HEAD='$head_field' (want non-zero exit, no PRIMARY_HEAD)"
fi

# --- Case 9: F8 regression — PRIMARY_STATE_FILE must be absolute, and `assert` must find it when
# invoked from a DIFFERENT cwd than `snapshot` (the PE playbook's Step 4 prompt contract mandates
# the agent `cd` into $WORKTREE between the two calls — differing cwd is the normal case, not an
# edge case).
c9="$work/c9"; repo9="$c9/repo"; make_repo "$repo9"
otherdir="$work/c9-elsewhere"; mkdir -p "$otherdir"
snap_out="$(run_in "$c9" snapshot "$repo9")"
state_file="$(get_field "$snap_out" PRIMARY_STATE_FILE)"
case "$state_file" in
  /*) pass "PRIMARY_STATE_FILE is absolute (F8): $state_file" ;;
  *)  fail "F8 regression — PRIMARY_STATE_FILE is relative: '$state_file'" ;;
esac
# Invoke assert from a cwd that is NEITHER $c9 nor the repo — a relative state_file would resolve
# to a nonexistent file here and hit the missing-state-file hard error.
assert_out="$(run_in "$otherdir" assert "$repo9" "$state_file")"; assert_rc=$?
integrity="$(get_field "$assert_out" WORKSPACE_INTEGRITY)"
violation="$(get_field "$assert_out" WORKSPACE_VIOLATION)"
if [ "$assert_rc" -eq 0 ] && [ "$integrity" = "OK" ] && [ "$violation" = "none" ]; then
  pass "assert from a different cwd than snapshot still finds the state file (F8)"
else
  fail "F8 regression — assert from different cwd got assert_rc=$assert_rc integrity=$integrity violation=$violation (want OK/none)"
fi

# seed_initialised_memories <repo-dir> — commits a placeholder file under .claude/memories/ so the
# repo matches a real post-`/sdlc:init` checkout (where agents/**/.gitkeep, reviews/.gitkeep etc.
# are already tracked). Without this, git's untracked-directory collapse in a bare scratch repo
# stops at the highest never-tracked ancestor (`.claude/`), not at `.claude/memories/captured/` —
# a fixture artifact that does not reproduce the real repo shape the fix targets.
seed_initialised_memories() {
  local repo="$1"
  mkdir -p "$repo/.claude/memories/agents/shared"
  : > "$repo/.claude/memories/agents/shared/.gitkeep"
  git -C "$repo" add .claude
  git -C "$repo" commit -q -m "seed .claude/memories (init scaffold)"
}

# --- Case 10 (NA-98 fix-round): a capture write in the primary's default staging root is never
# a violation — snapshot -> write a capture (default SDLC_CAPTURE_ROOT resolution) -> assert OK.
c10="$work/c10"; repo10="$c10/repo"; make_repo "$repo10"; seed_initialised_memories "$repo10"
cap_script="$scripts_dir/capture-learning.sh"
snap_out="$(run_in "$c10" snapshot "$repo10")"
state_file="$(get_field "$snap_out" PRIMARY_STATE_FILE)"
cap_out10="$( cd "$c10" && SDLC_CAPTURE_ROOT="$repo10/.claude/memories/captured" bash "$cap_script" rule web-engineer/na98-fixround-test AB-1 )"
printf '%s' "$cap_out10" | grep -q '^CAPTURED=' \
  && pass "Case 10 setup: the capture actually wrote a file" \
  || fail "Case 10 setup: capture-learning.sh did not print CAPTURED=" "got '$cap_out10'"
assert_out="$(run_in "$c10" assert "$repo10" "$state_file")"; assert_rc=$?
integrity="$(get_field "$assert_out" WORKSPACE_INTEGRITY)"
violation="$(get_field "$assert_out" WORKSPACE_VIOLATION)"
if [ "$assert_rc" -eq 0 ] && [ "$integrity" = "OK" ] && [ "$violation" = "none" ]; then
  pass "a capture write in the staging root is never a workspace-integrity violation"
else
  fail "capture write flagged a violation — got assert_rc=$assert_rc integrity=$integrity violation=$violation (want OK/none)"
fi

# --- Case 11 (NA-98 fix-round): a real stray file OUTSIDE the staging root still trips the guard,
# proving the exclusion is scoped to the capture root only, not a general relaxation.
c11="$work/c11"; repo11="$c11/repo"; make_repo "$repo11"; seed_initialised_memories "$repo11"
snap_out="$(run_in "$c11" snapshot "$repo11")"
state_file="$(get_field "$snap_out" PRIMARY_STATE_FILE)"
( cd "$c11" && SDLC_CAPTURE_ROOT="$repo11/.claude/memories/captured" bash "$cap_script" rule web-engineer/na98-fixround-test-2 AB-1 >/dev/null )
printf 'not a capture\n' > "$repo11/stray-file.txt"
assert_out="$(run_in "$c11" assert "$repo11" "$state_file")"; assert_rc=$?
integrity="$(get_field "$assert_out" WORKSPACE_INTEGRITY)"
violation="$(get_field "$assert_out" WORKSPACE_VIOLATION)"
if [ "$assert_rc" -eq 0 ] && [ "$integrity" = "VIOLATED" ] && [ "$violation" = "worktree-changed" ]; then
  pass "a stray file outside the staging root still trips VIOLATED (exclusion is scoped, not general)"
else
  fail "stray file outside staging root did not trip the guard — got assert_rc=$assert_rc integrity=$integrity violation=$violation (want VIOLATED/worktree-changed)"
fi

# --- Case 12 (NA-98 fix-round): SDLC_CAPTURE_ROOT override, pointed OUTSIDE .claude/memories/,
# is honoured — the exclusion follows the env var, never a hardcoded .claude/memories/captured path.
c12="$work/c12"; repo12="$c12/repo"; make_repo "$repo12"
custom_root="$repo12/tmp-capture-override"
snap_out="$(run_in "$c12" snapshot "$repo12")"
state_file="$(get_field "$snap_out" PRIMARY_STATE_FILE)"
cap_out12="$( cd "$c12" && SDLC_CAPTURE_ROOT="$custom_root" bash "$cap_script" rule web-engineer/na98-fixround-test-3 AB-1 )"
printf '%s' "$cap_out12" | grep -q '^CAPTURED=' \
  && pass "Case 12 setup: the capture actually wrote a file" \
  || fail "Case 12 setup: capture-learning.sh did not print CAPTURED=" "got '$cap_out12'"
assert_out="$(SDLC_CAPTURE_ROOT="$custom_root" run_in "$c12" assert "$repo12" "$state_file")"; assert_rc=$?
integrity="$(get_field "$assert_out" WORKSPACE_INTEGRITY)"
violation="$(get_field "$assert_out" WORKSPACE_VIOLATION)"
if [ "$assert_rc" -eq 0 ] && [ "$integrity" = "OK" ] && [ "$violation" = "none" ]; then
  pass "SDLC_CAPTURE_ROOT override outside .claude/memories/ is honoured by the exclusion"
else
  fail "SDLC_CAPTURE_ROOT override not honoured — got assert_rc=$assert_rc integrity=$integrity violation=$violation (want OK/none)"
fi

echo
if [ "$failures" -ne 0 ]; then
  echo "assert-workspace-clean.test.sh: FAILED ($failures assertion(s) failed)"
  exit 1
fi
echo "assert-workspace-clean.test.sh: PASS — all assertions passed"
exit 0
