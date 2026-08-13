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
# empty/neutral state.
cat >"$mockdir/gh" <<'MOCK_GH'
#!/usr/bin/env bash
set -uo pipefail
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

if [ "$failures" -eq 0 ]; then
  echo "PASS: all pr-loop-status.sh regression cases passed"
  exit 0
else
  echo "FAIL: $failures pr-loop-status.sh regression case(s) failed"
  exit 1
fi
