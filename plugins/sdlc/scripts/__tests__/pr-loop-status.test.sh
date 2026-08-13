#!/usr/bin/env bash
# pr-loop-status.test.sh — regression test pinning the unprotected-repo checks-gate fallback.
#
# pr-loop-status.sh reported checks-pending/checks-failing purely off `gh pr checks --required`,
# which returns ONLY branch-protection-required checks. On a repo with no branch protection
# (GitHub's default), that call returns `[]` even while CI is genuinely pending — so the loop's
# rule-4 clean-exit gate was a no-op and `--on-clean` could auto-merge before CI ever reported.
# The fix falls back to the unfiltered `gh pr checks --json bucket` ONLY when the required-only
# call comes back empty, so a protected repo (required checks present) is unaffected and an
# unprotected repo still waits on CI.
#
# This mocks `gh` end to end (pr view, pr checks x2, api graphql, api repos/.../reviews) so the
# script runs its real logic; only the checks fixtures vary per case below.
#
# Self-runnable, no test harness/framework dependency:
#   bash plugins/sdlc/scripts/__tests__/pr-loop-status.test.sh
# Exit 0 = PASS (all cases), non-zero = FAIL (any case).
set -uo pipefail

here="${BASH_SOURCE[0]%/*}"; [ "$here" = "${BASH_SOURCE[0]}" ] && here="."
script="$(cd "$here/.." && pwd)/pr-loop-status.sh"

mockdir="$(mktemp -d)"
trap 'rm -rf "$mockdir"' EXIT

# Mock `gh`. Fixtures are supplied via env vars so each case below only needs to set the checks
# ones — everything else (head oid, review requests, reviews, review threads) defaults to an
# empty/neutral state. Every invocation is appended to $GH_CALL_LOG (when set) so the
# malformed-input case can assert `gh` was never reached.
cat >"$mockdir/gh" <<'MOCK_GH'
#!/usr/bin/env bash
set -uo pipefail
[ -n "${GH_CALL_LOG:-}" ] && printf '%s\n' "$*" >>"$GH_CALL_LOG"
case "${1:-}" in
  repo)
    [ "${2:-}" = "view" ] && { echo "example-org/example-repo"; exit 0; }
    ;;
  pr)
    case "${2:-}" in
      view)
        for arg in "$@"; do
          case "$arg" in
            headRefOid) echo "${MOCK_HEAD_OID:-sha123}"; exit 0 ;;
            reviewRequests) echo "${MOCK_REVIEW_REQUESTS:-{\"reviewRequests\":[]\}}"; exit 0 ;;
          esac
        done
        echo '{}'
        exit 0
        ;;
      checks)
        required=0
        for arg in "$@"; do
          [ "$arg" = "--required" ] && required=1
        done
        if [ "$required" -eq 1 ]; then
          echo "${MOCK_CHECKS_REQUIRED:-[]}"
        else
          echo "${MOCK_CHECKS_ALL:-[]}"
        fi
        exit 0
        ;;
    esac
    ;;
  api)
    case "${2:-}" in
      graphql)
        jqexpr=""
        prev=""
        for arg in "$@"; do
          if [ "$prev" = "--jq" ]; then jqexpr="$arg"; fi
          prev="$arg"
        done
        payload="{\"data\":{\"repository\":{\"pullRequest\":{\"reviewThreads\":{\"pageInfo\":{\"hasNextPage\":false,\"endCursor\":null},\"nodes\":${MOCK_THREADS_JSON:-[]}}}}}}"
        echo "$payload" | jq -c "$jqexpr" 2>/dev/null
        exit 0
        ;;
      repos/*)
        echo "${MOCK_REVIEWS_RAW:-[]}"
        exit 0
        ;;
    esac
    ;;
esac
echo "mock gh: unhandled invocation: $*" >&2
exit 1
MOCK_GH
chmod +x "$mockdir/gh"

failures=0

field() { printf '%s\n' "$1" | grep -o "${2}=[0-9]*" | sed "s/${2}=//"; }

run() { # <label> <required_json> <all_json>
  MOCK_CHECKS_REQUIRED="$2" MOCK_CHECKS_ALL="$3" \
    PATH="$mockdir:$PATH" bash "$script" 999999 2>/dev/null
}

# Case 1: required checks exist and are pending -> reported pending (protected-repo path unchanged).
out1="$(run case1 '[{"bucket":"pending"}]' '[{"bucket":"pending"},{"bucket":"pass"}]')"
p1="$(field "$out1" checks-pending)"; f1="$(field "$out1" checks-failing)"; s1="$(field "$out1" checks-passing)"
if [ "$p1" = "1" ] && [ "$f1" = "0" ] && [ "$s1" = "0" ]; then
  echo "PASS: (1) required checks exist and are pending -> reported pending"
else
  echo "FAIL: (1) required checks pending — got pending=$p1 failing=$f1 passing=$s1 (line: $out1)"
  failures=$((failures + 1))
fi

# Case 2: required checks exist and pass -> reported passing.
out2="$(run case2 '[{"bucket":"pass"}]' '[{"bucket":"pass"},{"bucket":"pending"}]')"
p2="$(field "$out2" checks-pending)"; f2="$(field "$out2" checks-failing)"; s2="$(field "$out2" checks-passing)"
if [ "$p2" = "0" ] && [ "$f2" = "0" ] && [ "$s2" = "1" ]; then
  echo "PASS: (2) required checks exist and pass -> reported passing"
else
  echo "FAIL: (2) required checks passing — got pending=$p2 failing=$f2 passing=$s2 (line: $out2)"
  failures=$((failures + 1))
fi

# Case 3 (regression pin): no required checks (unprotected repo) but a pending NON-required
# check exists -> must fall back to the unfiltered check list and report pending, NOT green.
out3="$(run case3 '[]' '[{"bucket":"pending"}]')"
p3="$(field "$out3" checks-pending)"; f3="$(field "$out3" checks-failing)"; s3="$(field "$out3" checks-passing)"
if [ "$p3" = "1" ] && [ "$f3" = "0" ] && [ "$s3" = "0" ]; then
  echo "PASS: (3) no required checks + pending non-required check -> reported pending (regression pin)"
else
  echo "FAIL: (3) unprotected-repo fallback — got pending=$p3 failing=$f3 passing=$s3 (line: $out3), expected pending=1"
  failures=$((failures + 1))
fi

# Case 4: no checks at all (neither required nor any) -> zeros, no crash.
out4="$(run case4 '[]' '[]')"
status4=$?
p4="$(field "$out4" checks-pending)"; f4="$(field "$out4" checks-failing)"; s4="$(field "$out4" checks-passing)"
if [ "$status4" -eq 0 ] && [ "$p4" = "0" ] && [ "$f4" = "0" ] && [ "$s4" = "0" ]; then
  echo "PASS: (4) no checks at all -> zeros, no crash"
else
  echo "FAIL: (4) no checks at all — exit=$status4 pending=$p4 failing=$f4 passing=$s4 (line: $out4)"
  failures=$((failures + 1))
fi

# Cases 5-7 (regression pin): this script's own best-effort/always-zeros contract means a
# `loop-status:` line appears EVEN WITH A BLANK PR_NUM pre-fix (every gh call it makes falls back
# to zeros on failure) — asserting only "a loop-status: line appeared" would not pin the bug. The
# real pin is that `gh` must be called with the correctly normalised PR number threaded through,
# not a blank one (e.g. `pulls//reviews` / `pr checks ` pre-fix vs `pulls/999999/reviews` /
# `pr checks 999999` post-fix) — checked via the call log.
assert_pr_num_threaded() { # <label> <call_log> <stderr_log> <status> <expect_pr_num>
  local label="$1" call_log="$2" stderr_log="$3" status="$4" want="$5"
  if [ "$status" -eq 0 ] && grep -q "pulls/${want}/reviews" "$call_log" && grep -q "checks ${want} " "$call_log"; then
    echo "PASS: $label"
  else
    echo "FAIL: $label — status=$status"
    echo "--- gh call log ---"; cat "$call_log"
    echo "--- script stderr ---"; cat "$stderr_log"
    failures=$((failures + 1))
  fi
}

slash_stderr="$mockdir/stderr-slash.log"; slash_calls="$mockdir/gh-calls-slash.log"; : >"$slash_calls"
PATH="$mockdir:$PATH" GH_CALL_LOG="$slash_calls" bash "$script" "https://github.com/o/r/pull/999999/" >/dev/null 2>"$slash_stderr"
assert_pr_num_threaded "(5) a PR URL with a trailing slash normalises and threads PR_NUM=999999 through to gh" \
  "$slash_calls" "$slash_stderr" "$?" "999999"

frag_stderr="$mockdir/stderr-frag.log"; frag_calls="$mockdir/gh-calls-frag.log"; : >"$frag_calls"
PATH="$mockdir:$PATH" GH_CALL_LOG="$frag_calls" bash "$script" "https://github.com/o/r/pull/999999#discussion_r1" >/dev/null 2>"$frag_stderr"
assert_pr_num_threaded "(6) a PR URL with a #fragment normalises and threads PR_NUM=999999 through to gh" \
  "$frag_calls" "$frag_stderr" "$?" "999999"

query_stderr="$mockdir/stderr-query.log"; query_calls="$mockdir/gh-calls-query.log"; : >"$query_calls"
PATH="$mockdir:$PATH" GH_CALL_LOG="$query_calls" bash "$script" "https://github.com/o/r/pull/999999?tab=files" >/dev/null 2>"$query_stderr"
assert_pr_num_threaded "(7) a PR URL with a ?query normalises and threads PR_NUM=999999 through to gh" \
  "$query_calls" "$query_stderr" "$?" "999999"

# Case 8: a genuinely malformed input (no trailing digits at all) must be rejected with a clear
# error BEFORE it ever reaches `gh`, and must NOT print a loop-status: line — matching this
# script's own "best-effort, always exits 0, a probe failure prints zeros" contract, the ABSENCE
# of the line (not a fabricated all-zero one) is what routes loop-decide.sh to "unresolvable".
malformed_stderr="$mockdir/stderr-malformed.log"
malformed_call_log="$mockdir/gh-calls-malformed.log"
: >"$malformed_call_log"
malformed_out="$(PATH="$mockdir:$PATH" GH_CALL_LOG="$malformed_call_log" bash "$script" "https://github.com/o/r/pull/" 2>"$malformed_stderr")"
malformed_status=$?
if [ "$malformed_status" -eq 0 ] \
  && ! printf '%s\n' "$malformed_out" | grep -q '^loop-status:' \
  && grep -q 'not a valid PR number or URL' "$malformed_stderr" \
  && [ ! -s "$malformed_call_log" ]; then
  echo "PASS: (8) malformed input is rejected with a clear error, never reaching gh, no loop-status: line"
else
  echo "FAIL: (8) malformed input — exit=$malformed_status output=${malformed_out:-<empty>} gh-calls=$(cat "$malformed_call_log" 2>/dev/null)"
  echo "--- script stderr ---"; cat "$malformed_stderr"
  failures=$((failures + 1))
fi

# Cases 9-12 (regression pin): ordinary GitHub PR URLs copied from a PR sub-tab (Files
# changed/Commits), a double trailing slash, and whitespace-padded input must all normalise and
# thread PR_NUM=999999 through to gh (same call-log discipline as cases 5-7 — see their comment).
files_stderr="$mockdir/stderr-files.log"; files_calls="$mockdir/gh-calls-files.log"; : >"$files_calls"
PATH="$mockdir:$PATH" GH_CALL_LOG="$files_calls" bash "$script" "https://github.com/o/r/pull/999999/files" >/dev/null 2>"$files_stderr"
assert_pr_num_threaded "(9) a /pull/N/files URL (Files changed tab) normalises and threads PR_NUM=999999 through to gh" \
  "$files_calls" "$files_stderr" "$?" "999999"

commits_stderr="$mockdir/stderr-commits.log"; commits_calls="$mockdir/gh-calls-commits.log"; : >"$commits_calls"
PATH="$mockdir:$PATH" GH_CALL_LOG="$commits_calls" bash "$script" "https://github.com/o/r/pull/999999/commits" >/dev/null 2>"$commits_stderr"
assert_pr_num_threaded "(10) a /pull/N/commits URL (Commits tab) normalises and threads PR_NUM=999999 through to gh" \
  "$commits_calls" "$commits_stderr" "$?" "999999"

dblslash_stderr="$mockdir/stderr-dblslash.log"; dblslash_calls="$mockdir/gh-calls-dblslash.log"; : >"$dblslash_calls"
PATH="$mockdir:$PATH" GH_CALL_LOG="$dblslash_calls" bash "$script" "https://github.com/o/r/pull/999999//" >/dev/null 2>"$dblslash_stderr"
assert_pr_num_threaded "(11) a PR URL with a double trailing slash normalises and threads PR_NUM=999999 through to gh" \
  "$dblslash_calls" "$dblslash_stderr" "$?" "999999"

ws_stderr="$mockdir/stderr-ws.log"; ws_calls="$mockdir/gh-calls-ws.log"; : >"$ws_calls"
PATH="$mockdir:$PATH" GH_CALL_LOG="$ws_calls" bash "$script" " 999999 " >/dev/null 2>"$ws_stderr"
assert_pr_num_threaded "(12) whitespace-padded input normalises and threads PR_NUM=999999 through to gh" \
  "$ws_calls" "$ws_stderr" "$?" "999999"

# Cases 13-14: widening acceptance must not regress the rejection path — genuinely malformed
# input (/pull/abc, a bare non-numeric string) is still rejected before reaching gh, with no
# loop-status: line.
reject_case() { # <n> <label> <input>
  local n="$1" label="$2" input="$3" stderr call_log out status
  stderr="$mockdir/stderr-$n.log"
  call_log="$mockdir/gh-calls-$n.log"
  : >"$call_log"
  out="$(PATH="$mockdir:$PATH" GH_CALL_LOG="$call_log" bash "$script" "$input" 2>"$stderr")"
  status=$?
  if [ "$status" -eq 0 ] \
    && ! printf '%s\n' "$out" | grep -q '^loop-status:' \
    && grep -q 'not a valid PR number or URL' "$stderr" \
    && [ ! -s "$call_log" ]; then
    echo "PASS: ($n) $label"
  else
    echo "FAIL: ($n) $label — exit=$status output=${out:-<empty>} gh-calls=$(cat "$call_log" 2>/dev/null)"
    echo "--- script stderr ---"; cat "$stderr"
    failures=$((failures + 1))
  fi
}
reject_case 13 "a /pull/abc URL (non-numeric PR segment) is still rejected, never reaching gh" \
  "https://github.com/o/r/pull/abc"
reject_case 14 "a bare non-URL, non-numeric string is still rejected, never reaching gh" \
  "notaurl"

if [ "$failures" -eq 0 ]; then
  echo "PASS: all pr-loop-status.sh regression cases passed"
  exit 0
else
  echo "FAIL: $failures pr-loop-status.sh regression case(s) failed"
  exit 1
fi
