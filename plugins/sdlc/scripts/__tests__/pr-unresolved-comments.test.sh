#!/usr/bin/env bash
# pr-unresolved-comments.test.sh — regression test pinning the PR-URL normalisation fix.
#
# pr-unresolved-comments.sh took `$1` raw and passed it straight into a GraphQL `$n:Int!`
# variable. Every real caller (auto.md, impl.md, adr-pipeline.md, loop-decide.sh) passes a full
# PR URL, and commands/loop.md documents a URL as valid input — but a URL is not a valid Int, so
# `gh api graphql` rejected it ("Variable $n of type Int! was provided invalid value"). This
# mocks `gh` to reproduce that exact contract:
#   - `gh repo view --json nameWithOwner -q .nameWithOwner` -> a repo slug.
#   - `gh api graphql ... -F n=<value> --jq <expr>` -> validates <value> looks like a GitHub Int
#     (same shape `gh` itself enforces), THEN pipes a realistic reviewThreads payload through the
#     REAL jq binary using the script's own --jq expression, so a broken jq expression fails the
#     test too.
#
# Self-runnable, no test harness/framework dependency:
#   bash plugins/sdlc/scripts/__tests__/pr-unresolved-comments.test.sh
# Exit 0 = PASS (all cases), non-zero = FAIL (any case).
set -uo pipefail

here="${BASH_SOURCE[0]%/*}"; [ "$here" = "${BASH_SOURCE[0]}" ] && here="."
script="$(cd "$here/.." && pwd)/pr-unresolved-comments.sh"

mockdir="$(mktemp -d)"
trap 'rm -rf "$mockdir"' EXIT

# Mock `gh` mirroring the real gh contract this script depends on. The reviewThreads payload is
# read from $MOCK_THREADS_JSON (a JSON array of thread nodes) so each case below can supply its
# own fixture without touching the mock. Every invocation is appended to $GH_CALL_LOG (when set)
# so the malformed-input case can assert `gh` was never reached.
cat >"$mockdir/gh" <<'MOCK_GH'
#!/usr/bin/env bash
set -uo pipefail
[ -n "${GH_CALL_LOG:-}" ] && printf '%s\n' "$*" >>"$GH_CALL_LOG"
case "${1:-}" in
  repo)
    [ "${2:-}" = "view" ] && { echo "example-org/example-repo"; exit 0; }
    ;;
  api)
    jqexpr=""
    n_value=""
    prev=""
    for arg in "$@"; do
      if [ "$prev" = "--jq" ]; then
        jqexpr="$arg"
      fi
      case "$prev" in
        -F)
          case "$arg" in
            n=*) n_value="${arg#n=}" ;;
          esac
          ;;
      esac
      prev="$arg"
    done
    # Real gh rejects a non-integer value for an Int! GraphQL variable with this exact message.
    case "$n_value" in
      ''|*[!0-9]*)
        echo "gh: Variable \$n of type Int! was provided invalid value" >&2
        exit 1
        ;;
    esac
    payload="{\"data\":{\"repository\":{\"pullRequest\":{\"reviewThreads\":{\"pageInfo\":{\"hasNextPage\":false,\"endCursor\":null},\"nodes\":${MOCK_THREADS_JSON:-[]}}}}}}"
    if [ -n "$jqexpr" ]; then
      echo "$payload" | jq -c "$jqexpr"
    else
      echo "$payload"
    fi
    exit 0
    ;;
esac
echo "mock gh: unhandled invocation: $*" >&2
exit 1
MOCK_GH
chmod +x "$mockdir/gh"

failures=0

# Fixture: three threads — one unresolved (1 comment), one resolved (must be excluded), one
# unresolved with 2 comments (proves multi-comment threads all flatten to NDJSON lines).
mixed_threads='[
  {"id":"THREAD_1","isResolved":false,"comments":{"nodes":[
    {"databaseId":101,"path":"a.ts","line":5,"originalLine":5,"body":"fix this","author":{"login":"copilot"}}
  ]}},
  {"id":"THREAD_2","isResolved":true,"comments":{"nodes":[
    {"databaseId":102,"path":"b.ts","line":9,"originalLine":9,"body":"already resolved","author":{"login":"alice"}}
  ]}},
  {"id":"THREAD_3","isResolved":false,"comments":{"nodes":[
    {"databaseId":103,"path":"c.ts","line":1,"originalLine":1,"body":"another","author":{"login":"bob"}},
    {"databaseId":104,"path":"c.ts","line":2,"originalLine":2,"body":"more","author":{"login":"bob"}}
  ]}}
]'

all_resolved_threads='[
  {"id":"THREAD_1","isResolved":true,"comments":{"nodes":[
    {"databaseId":201,"path":"a.ts","line":5,"originalLine":5,"body":"fixed","author":{"login":"copilot"}}
  ]}}
]'

# Case 1 (regression pin): a full PR URL must resolve and succeed — this is exactly the shape
# every real caller (auto.md, impl.md, adr-pipeline.md, loop-decide.sh) passes.
url_stderr="$mockdir/stderr-url.log"
url_out="$(PATH="$mockdir:$PATH" MOCK_THREADS_JSON="$mixed_threads" bash "$script" "https://github.com/whimzyLive/nightshift-ai/pull/239" 2>"$url_stderr")"
url_status=$?
url_count=$(printf '%s' "$url_out" | grep -c . || true)
if [ "$url_status" -eq 0 ] && [ "$url_count" -eq 3 ]; then
  echo "PASS: (1) a full PR URL resolves and succeeds (regression pin)"
else
  echo "FAIL: (1) a full PR URL resolves and succeeds — exit=$url_status lines=$url_count"
  echo "--- script stderr ---"; cat "$url_stderr"
  failures=$((failures + 1))
fi

# Case 2: a bare PR number must still work (no regression on the pre-existing call shape).
num_stderr="$mockdir/stderr-num.log"
num_out="$(PATH="$mockdir:$PATH" MOCK_THREADS_JSON="$mixed_threads" bash "$script" "239" 2>"$num_stderr")"
num_status=$?
num_count=$(printf '%s' "$num_out" | grep -c . || true)
if [ "$num_status" -eq 0 ] && [ "$num_count" -eq 3 ]; then
  echo "PASS: (2) a bare PR number still works"
else
  echo "FAIL: (2) a bare PR number still works — exit=$num_status lines=$num_count"
  echo "--- script stderr ---"; cat "$num_stderr"
  failures=$((failures + 1))
fi

# Case 3: unresolved threads are counted correctly — 1 comment on THREAD_1 + 2 comments on
# THREAD_3 = 3 NDJSON lines; THREAD_2 (resolved) must be fully excluded.
if printf '%s\n' "$num_out" | grep -q '"id":101' \
  && printf '%s\n' "$num_out" | grep -q '"id":103' \
  && printf '%s\n' "$num_out" | grep -q '"id":104' \
  && ! printf '%s\n' "$num_out" | grep -q '"id":102'; then
  echo "PASS: (3) unresolved threads are counted correctly (resolved thread excluded)"
else
  echo "FAIL: (3) unresolved threads are counted correctly — got: $num_out"
  failures=$((failures + 1))
fi

# Case 4: zero unresolved threads returns cleanly (empty NDJSON, count=0, exit 0).
zero_stderr="$mockdir/stderr-zero.log"
zero_out="$(PATH="$mockdir:$PATH" MOCK_THREADS_JSON="$all_resolved_threads" bash "$script" "239" 2>"$zero_stderr")"
zero_status=$?
if [ "$zero_status" -eq 0 ] && [ -z "$zero_out" ] && grep -q '^unresolved-inline-comments: 0$' "$zero_stderr"; then
  echo "PASS: (4) zero unresolved threads returns cleanly"
else
  echo "FAIL: (4) zero unresolved threads returns cleanly — exit=$zero_status output=${zero_out:-<empty>}"
  echo "--- script stderr ---"; cat "$zero_stderr"
  failures=$((failures + 1))
fi

# Case 5 (regression pin): a PR URL with a trailing slash (e.g. a pasted "/pull/239/") must still
# resolve — ${PR##*/} alone leaves this empty and re-triggers the GraphQL Int! failure.
slash_stderr="$mockdir/stderr-slash.log"
slash_out="$(PATH="$mockdir:$PATH" MOCK_THREADS_JSON="$mixed_threads" bash "$script" "https://github.com/whimzyLive/nightshift-ai/pull/239/" 2>"$slash_stderr")"
slash_status=$?
slash_count=$(printf '%s' "$slash_out" | grep -c . || true)
if [ "$slash_status" -eq 0 ] && [ "$slash_count" -eq 3 ]; then
  echo "PASS: (5) a PR URL with a trailing slash resolves and succeeds (regression pin)"
else
  echo "FAIL: (5) trailing-slash PR URL — exit=$slash_status lines=$slash_count"
  echo "--- script stderr ---"; cat "$slash_stderr"
  failures=$((failures + 1))
fi

# Case 6 (regression pin): a PR URL with a #fragment (e.g. "/pull/239#discussion_r1") must resolve.
frag_stderr="$mockdir/stderr-frag.log"
frag_out="$(PATH="$mockdir:$PATH" MOCK_THREADS_JSON="$mixed_threads" bash "$script" "https://github.com/whimzyLive/nightshift-ai/pull/239#discussion_r1" 2>"$frag_stderr")"
frag_status=$?
frag_count=$(printf '%s' "$frag_out" | grep -c . || true)
if [ "$frag_status" -eq 0 ] && [ "$frag_count" -eq 3 ]; then
  echo "PASS: (6) a PR URL with a #fragment resolves and succeeds (regression pin)"
else
  echo "FAIL: (6) #fragment PR URL — exit=$frag_status lines=$frag_count"
  echo "--- script stderr ---"; cat "$frag_stderr"
  failures=$((failures + 1))
fi

# Case 7 (regression pin): a PR URL with a ?query resolves too.
query_stderr="$mockdir/stderr-query.log"
query_out="$(PATH="$mockdir:$PATH" MOCK_THREADS_JSON="$mixed_threads" bash "$script" "https://github.com/whimzyLive/nightshift-ai/pull/239?tab=files" 2>"$query_stderr")"
query_status=$?
query_count=$(printf '%s' "$query_out" | grep -c . || true)
if [ "$query_status" -eq 0 ] && [ "$query_count" -eq 3 ]; then
  echo "PASS: (7) a PR URL with a ?query resolves and succeeds (regression pin)"
else
  echo "FAIL: (7) ?query PR URL — exit=$query_status lines=$query_count"
  echo "--- script stderr ---"; cat "$query_stderr"
  failures=$((failures + 1))
fi

# Case 8: a genuinely malformed input (no trailing digits at all) is rejected with a clear error
# BEFORE it ever reaches `gh` — proven via the call log, not inferred from exit status alone.
malformed_stderr="$mockdir/stderr-malformed.log"
malformed_call_log="$mockdir/gh-calls-malformed.log"
: >"$malformed_call_log"
malformed_out="$(PATH="$mockdir:$PATH" GH_CALL_LOG="$malformed_call_log" bash "$script" "https://github.com/whimzyLive/nightshift-ai/pull/" 2>"$malformed_stderr")"
malformed_status=$?
if [ "$malformed_status" -ne 0 ] && [ -z "$malformed_out" ] \
  && grep -q 'not a valid PR number or URL' "$malformed_stderr" \
  && [ ! -s "$malformed_call_log" ]; then
  echo "PASS: (8) malformed input is rejected with a clear error, never reaching gh"
else
  echo "FAIL: (8) malformed input — exit=$malformed_status output=${malformed_out:-<empty>} gh-calls=$(cat "$malformed_call_log" 2>/dev/null)"
  echo "--- script stderr ---"; cat "$malformed_stderr"
  failures=$((failures + 1))
fi

# Cases 9-12 (regression pin): ordinary GitHub PR URLs copied from a PR sub-tab (Files
# changed/Commits), a double trailing slash, and whitespace-padded input must all resolve.
accept_case() { # <n> <label> <input>
  local n="$1" label="$2" input="$3" stderr out status count
  stderr="$mockdir/stderr-$n.log"
  out="$(PATH="$mockdir:$PATH" MOCK_THREADS_JSON="$mixed_threads" bash "$script" "$input" 2>"$stderr")"
  status=$?
  count=$(printf '%s' "$out" | grep -c . || true)
  if [ "$status" -eq 0 ] && [ "$count" -eq 3 ]; then
    echo "PASS: ($n) $label"
  else
    echo "FAIL: ($n) $label — exit=$status lines=$count"
    echo "--- script stderr ---"; cat "$stderr"
    failures=$((failures + 1))
  fi
}
accept_case 9  "a /pull/N/files URL (Files changed tab) resolves and succeeds" \
  "https://github.com/whimzyLive/nightshift-ai/pull/239/files"
accept_case 10 "a /pull/N/commits URL (Commits tab) resolves and succeeds" \
  "https://github.com/whimzyLive/nightshift-ai/pull/239/commits"
accept_case 11 "a PR URL with a double trailing slash resolves and succeeds" \
  "https://github.com/whimzyLive/nightshift-ai/pull/239//"
accept_case 12 "whitespace-padded input resolves and succeeds" \
  " 239 "

# Cases 13-14: widening acceptance must not regress the rejection path — genuinely malformed
# input (/pull/abc, a bare non-numeric string) is still rejected before reaching gh.
reject_case() { # <n> <label> <input>
  local n="$1" label="$2" input="$3" stderr call_log out status
  stderr="$mockdir/stderr-$n.log"
  call_log="$mockdir/gh-calls-$n.log"
  : >"$call_log"
  out="$(PATH="$mockdir:$PATH" GH_CALL_LOG="$call_log" bash "$script" "$input" 2>"$stderr")"
  status=$?
  if [ "$status" -ne 0 ] && [ -z "$out" ] \
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
  "https://github.com/whimzyLive/nightshift-ai/pull/abc"
reject_case 14 "a bare non-URL, non-numeric string is still rejected, never reaching gh" \
  "notaurl"

if [ "$failures" -eq 0 ]; then
  echo "PASS: all pr-unresolved-comments.sh regression cases passed"
  exit 0
else
  echo "FAIL: $failures pr-unresolved-comments.sh regression case(s) failed"
  exit 1
fi
