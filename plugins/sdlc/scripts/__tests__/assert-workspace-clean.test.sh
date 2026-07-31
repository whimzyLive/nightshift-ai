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

# --- Case 6: missing state file -> VIOLATED/both (fail closed) -----------------------
c6="$work/c6"; repo6="$c6/repo"; make_repo "$repo6"
assert_out="$(run_in "$c6" assert "$repo6" "$c6/does-not-exist")"; assert_rc=$?
integrity="$(get_field "$assert_out" WORKSPACE_INTEGRITY)"
violation="$(get_field "$assert_out" WORKSPACE_VIOLATION)"
if [ "$assert_rc" -eq 0 ] && [ "$integrity" = "VIOLATED" ] && [ "$violation" = "both" ]; then
  pass "missing state file -> VIOLATED/both, fail closed"
else
  fail "missing state file — got assert_rc=$assert_rc integrity=$integrity violation=$violation"
fi

# --- Case 7: every row exits 0 (checked inline above) — explicit summary assertion ---
# snapshot and assert never signal the decision via exit code — re-confirm on a fresh clean pair.
c7="$work/c7"; repo7="$c7/repo"; make_repo "$repo7"
run_in "$c7" snapshot "$repo7" >/dev/null; snap_rc=$?
run_in "$c7" assert "$repo7" "$c7/does-not-exist" >/dev/null; assert_rc=$?
if [ "$snap_rc" -eq 0 ] && [ "$assert_rc" -eq 0 ]; then
  pass "every row exits 0 (decision lives in stdout, not exit code)"
else
  fail "row exit codes — got snap_rc=$snap_rc assert_rc=$assert_rc, want 0 0"
fi

echo
if [ "$failures" -ne 0 ]; then
  echo "assert-workspace-clean.test.sh: FAILED ($failures assertion(s) failed)"
  exit 1
fi
echo "assert-workspace-clean.test.sh: PASS — all assertions passed"
exit 0
