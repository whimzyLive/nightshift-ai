#!/usr/bin/env bash
# auto-merge-pr.test.sh — regression test pinning the gh `pr merge --yes` removal (NA-45).
#
# gh >=2.90 dropped the `--yes` flag from `gh pr merge` ("unknown flag: --yes"). This test mocks
# `gh` to reproduce that exact contract and covers:
#   1. Happy path — the 1-arg back-compat call must print MERGED and exit 0 through a gh that
#      rejects --yes. The mock `gh api` pipes a realistic repos/<slug> JSON payload through the
#      REAL `jq` binary using the exact --jq expression auto-merge-pr.sh passes (line 67), so the
#      script's own method-resolution logic actually runs here rather than being stubbed out.
#   2. Failure contract — on a merge rejection (branch protection / conflict / checks not met),
#      the script must exit non-zero and print an `ERROR: gh pr merge ... failed` line to stderr
#      so sdlc:loop can detect it (the bug's own Expected Result).
#
# Self-runnable, no test harness/framework dependency:
#   bash plugins/sdlc/scripts/__tests__/auto-merge-pr.test.sh
# Exit 0 = PASS (all cases), non-zero = FAIL (any case).
set -uo pipefail

here="${BASH_SOURCE[0]%/*}"; [ "$here" = "${BASH_SOURCE[0]}" ] && here="."
script="$(cd "$here/.." && pwd)/auto-merge-pr.sh"

mockdir="$(mktemp -d)"
trap 'rm -rf "$mockdir"' EXIT

# Mock `gh` mirroring the real gh (>=2.90) contract this script depends on:
#   - `gh repo view --json nameWithOwner -q .nameWithOwner`  -> a repo slug
#   - `gh api repos/<slug> --jq '<expr>'`                     -> the script's own <expr> evaluated
#                                                                (by the real jq binary) against a
#                                                                realistic repo-settings payload,
#                                                                so a broken expr fails the test.
#   - `gh pr merge <pr> <method> --yes`                       -> "unknown flag: --yes", exit 1
#   - `gh pr merge <pr> <method>` (no --yes)                  -> exit 0, unless
#                                                                MOCK_GH_MERGE_REJECT=1 is set, in
#                                                                which case it exits 1 with a
#                                                                realistic rejection message on
#                                                                stderr (branch protection etc.).
#   - `gh pr view <pr> --json state -q .state`                -> MERGED
cat >"$mockdir/gh" <<'MOCK_GH'
#!/usr/bin/env bash
set -uo pipefail
case "${1:-}" in
  repo)
    [ "${2:-}" = "view" ] && { echo "example-org/example-repo"; exit 0; }
    ;;
  api)
    jqexpr=""
    prev=""
    for arg in "$@"; do
      if [ "$prev" = "--jq" ]; then
        jqexpr="$arg"
      fi
      prev="$arg"
    done
    payload='{"allow_merge_commit":true,"allow_squash_merge":true,"allow_rebase_merge":true}'
    if [ -n "$jqexpr" ]; then
      echo "$payload" | jq -r "$jqexpr"
    else
      echo "$payload"
    fi
    exit 0
    ;;
  pr)
    case "${2:-}" in
      merge)
        for arg in "$@"; do
          if [ "$arg" = "--yes" ]; then
            echo "unknown flag: --yes" >&2
            exit 1
          fi
        done
        # Validate the resolved method flag the same way real gh would reject an unrecognized
        # one — this is what makes a broken method-resolution jq expression (line 67) actually
        # fail the test instead of merging "successfully" with a bogus flag.
        case "${4:-}" in
          --merge|--squash|--rebase) : ;;
          *)
            echo "unknown flag: ${4:-<missing>}" >&2
            exit 1
            ;;
        esac
        if [ "${MOCK_GH_MERGE_REJECT:-}" = "1" ]; then
          echo "GraphQL: Pull Request is not mergeable: at least 1 approving review is required by reviewers with write access (mergePullRequest)" >&2
          exit 1
        fi
        echo "Merged pull request #${3:-}"
        exit 0
        ;;
      view)
        echo "MERGED"
        exit 0
        ;;
    esac
    ;;
esac
echo "mock gh: unhandled invocation: $*" >&2
exit 1
MOCK_GH
chmod +x "$mockdir/gh"

# Stub `acli` as a harmless no-op so the 1-arg path (no STORY_KEY/DONE_STATUS, transition block
# skipped entirely) is exercised cleanly even if it were ever invoked. The 3-arg Jira-transition
# path is out of scope for this bug (method-resolution / merge-flag / failure-contract only).
cat >"$mockdir/acli" <<'MOCK_ACLI'
#!/usr/bin/env bash
exit 0
MOCK_ACLI
chmod +x "$mockdir/acli"

failures=0

# Case 1: happy path — 1-arg back-compat, gh rejects --yes (pins the removed-flag fix), and
# method resolution runs through the script's real jq expression against a realistic payload.
happy_stderr="$mockdir/stderr-happy.log"
happy_out="$(PATH="$mockdir:$PATH" bash "$script" 999999 2>"$happy_stderr")"
happy_status=$?
if [ "$happy_status" -eq 0 ] && [ "$happy_out" = "MERGED" ]; then
  echo "PASS: happy path — auto-merge-pr.sh (1-arg) exits 0 and prints MERGED under a gh that rejects --yes"
else
  echo "FAIL: happy path — exit=$happy_status output=${happy_out:-<empty>}"
  echo "--- script stderr ---"
  cat "$happy_stderr"
  failures=$((failures + 1))
fi

# Case 2: merge-rejection failure contract — branch-protection/conflict/checks-not-met must exit
# non-zero and surface the `ERROR: gh pr merge ... failed` line so sdlc:loop can detect it.
reject_stderr="$mockdir/stderr-reject.log"
reject_out="$(PATH="$mockdir:$PATH" MOCK_GH_MERGE_REJECT=1 bash "$script" 999999 2>"$reject_stderr")"
reject_status=$?
if [ "$reject_status" -ne 0 ] && [ -z "$reject_out" ] && grep -q '^ERROR: gh pr merge .* failed' "$reject_stderr"; then
  echo "PASS: merge-rejection — auto-merge-pr.sh exits non-zero and prints the ERROR: gh pr merge ... failed line"
else
  echo "FAIL: merge-rejection — exit=$reject_status output=${reject_out:-<empty>}"
  echo "--- script stderr ---"
  cat "$reject_stderr"
  failures=$((failures + 1))
fi

if [ "$failures" -eq 0 ]; then
  echo "PASS: all auto-merge-pr.sh regression cases passed"
  exit 0
else
  echo "FAIL: $failures auto-merge-pr.sh regression case(s) failed"
  exit 1
fi
