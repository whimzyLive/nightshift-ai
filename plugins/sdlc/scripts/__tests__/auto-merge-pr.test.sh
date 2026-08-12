#!/usr/bin/env bash
# auto-merge-pr.test.sh — regression test pinning the gh `pr merge --yes` removal (NA-45) and the
# `--auto` branch (NA-104).
#
# gh >=2.90 dropped the `--yes` flag from `gh pr merge` ("unknown flag: --yes"). This test mocks
# `gh` to reproduce that exact contract and covers:
#   1. Happy path — the 1-arg back-compat call must print MERGED and exit 0 through a gh that
#      rejects --yes. The mock `gh api` returns a realistic repos/<slug> JSON payload; the script
#      pipes it through the REAL `jq` binary itself, so its own method-resolution logic actually
#      runs here rather than being stubbed out.
#   2. Failure contract — on a merge rejection (branch protection / conflict / checks not met),
#      the script must exit non-zero and print an `ERROR: gh pr merge ... failed` line to stderr
#      so sdlc:loop can detect it (the bug's own Expected Result).
#   3. `--auto` eligible + enable — armed but not yet merged: prints AUTO-MERGE-ENABLED, exit 0.
#   4. `--auto` + `allow_auto_merge=false` (NA-104 round-3 Critical A) — decided UP FRONT from
#      repo settings, never attempts `gh pr merge --auto` at all, merges immediately instead.
#   5. `--auto` + `mergeStateStatus=CLEAN` (NA-104 round-3 Critical A) — decided UP FRONT from PR
#      state, never attempts `gh pr merge --auto`, merges immediately instead.
#   6. `--auto` eligible per the up-front checks, but `gh pr merge --auto` itself still rejects
#      with "clean status" (defensive backstop for the race the up-front check can't close) —
#      falls back to an immediate merge instead of hard-failing.
#   7. `--auto` + merged inside the confirmation window (NA-104 round-2 Important 1) — accepts
#      `state == MERGED` as success instead of erroring because `autoMergeRequest` is null.
#   8. `--auto` eligible, but a genuine (non-"clean status") rejection — exits non-zero, does NOT
#      fall back.
#   9. `--auto` + story-key/done-status together — rejected as an invalid combination (a spec PR
#      never completes the story), enforced rather than merely documented.
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
#   - `gh api repos/<slug>` [--jq '<expr>']                   -> a repo-settings payload with
#                                                                `allow_auto_merge` selected by
#                                                                MOCK_GH_ALLOW_AUTO_MERGE (default
#                                                                true); piped through the REAL jq
#                                                                binary when --jq is given
#                                                                (back-compat with an older
#                                                                script that still passes it),
#                                                                otherwise returned as raw JSON.
#   - `gh pr merge <pr> <method> --yes`                       -> "unknown flag: --yes", exit 1
#   - `gh pr merge <pr> <method>` (no --auto, no --yes)       -> exit 0, unless
#                                                                MOCK_GH_MERGE_REJECT=1 is set, in
#                                                                which case it exits 1 with a
#                                                                realistic rejection message on
#                                                                stderr (branch protection etc.).
#   - `gh pr merge <pr> <method> --auto`                      -> behaviour selected by
#                                                                MOCK_GH_AUTO_MODE (enable |
#                                                                clean-status | reject; default
#                                                                enable).
#   - `gh pr view <pr> --json <field> -q <expr>`              -> <expr> evaluated (by the real jq
#                                                                binary) against {state:
#                                                                MOCK_GH_STATE (default MERGED),
#                                                                autoMergeRequest: MOCK_GH_AUTOMERGE
#                                                                (default null), mergeStateStatus:
#                                                                MOCK_GH_MERGE_STATE_STATUS
#                                                                (default BLOCKED)}
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
    allow_auto="${MOCK_GH_ALLOW_AUTO_MERGE:-true}"
    payload="{\"allow_merge_commit\":true,\"allow_squash_merge\":true,\"allow_rebase_merge\":true,\"allow_auto_merge\":$allow_auto}"
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
        # one — this is what makes a broken method-resolution jq expression fail the test instead
        # of merging "successfully" with a bogus flag.
        case "${4:-}" in
          --merge|--squash|--rebase) : ;;
          *)
            echo "unknown flag: ${4:-<missing>}" >&2
            exit 1
            ;;
        esac
        auto=0
        for arg in "$@"; do [ "$arg" = "--auto" ] && auto=1; done
        if [ "$auto" = 1 ]; then
          case "${MOCK_GH_AUTO_MODE:-enable}" in
            clean-status)
              echo "GraphQL: Pull request is in clean status (enablePullRequestAutoMerge)" >&2
              exit 1
              ;;
            reject)
              echo "GraphQL: auto-merge is not allowed for this repository (enablePullRequestAutoMerge)" >&2
              exit 1
              ;;
            *)
              echo "Auto-merge enabled for pull request #${3:-}"
              exit 0
              ;;
          esac
        fi
        if [ "${MOCK_GH_MERGE_REJECT:-}" = "1" ]; then
          echo "GraphQL: Pull Request is not mergeable: at least 1 approving review is required by reviewers with write access (mergePullRequest)" >&2
          exit 1
        fi
        echo "Merged pull request #${3:-}"
        exit 0
        ;;
      view)
        jqexpr=""
        prev=""
        for arg in "$@"; do
          if [ "$prev" = "-q" ]; then
            jqexpr="$arg"
          fi
          prev="$arg"
        done
        state="${MOCK_GH_STATE:-MERGED}"
        automerge="${MOCK_GH_AUTOMERGE:-null}"
        mss="${MOCK_GH_MERGE_STATE_STATUS:-BLOCKED}"
        payload="{\"state\":\"$state\",\"autoMergeRequest\":$automerge,\"mergeStateStatus\":\"$mss\"}"
        if [ -n "$jqexpr" ]; then
          echo "$payload" | jq -r "$jqexpr"
        else
          echo "$payload"
        fi
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

# Case 3: --auto eligible (allow_auto_merge=true, mergeStateStatus!=CLEAN) + enable — armed but
# not yet merged (state stays OPEN, autoMergeRequest set).
auto_stderr="$mockdir/stderr-auto.log"
auto_out="$(PATH="$mockdir:$PATH" MOCK_GH_ALLOW_AUTO_MERGE=true MOCK_GH_MERGE_STATE_STATUS=BLOCKED \
  MOCK_GH_AUTO_MODE=enable MOCK_GH_STATE=OPEN MOCK_GH_AUTOMERGE=true \
  bash "$script" --auto 999999 2>"$auto_stderr")"
auto_status=$?
if [ "$auto_status" -eq 0 ] && [ "$auto_out" = "AUTO-MERGE-ENABLED" ]; then
  echo "PASS: --auto eligible + enable — exits 0 and prints AUTO-MERGE-ENABLED when armed but not yet merged"
else
  echo "FAIL: --auto eligible + enable — exit=$auto_status output=${auto_out:-<empty>}"
  cat "$auto_stderr"
  failures=$((failures + 1))
fi

# Case 4: --auto + allow_auto_merge=false (round-3 Critical A — the default on every new GitHub
# repo) — must be decided UP FRONT and never even attempt `gh pr merge --auto`; merges
# immediately instead. MOCK_GH_AUTO_MODE=reject would make a wrongful --auto attempt visible via
# a DIFFERENT (non-MERGED) outcome, proving the up-front check actually skipped it.
noauto_stderr="$mockdir/stderr-noauto.log"
noauto_out="$(PATH="$mockdir:$PATH" MOCK_GH_ALLOW_AUTO_MERGE=false MOCK_GH_AUTO_MODE=reject MOCK_GH_STATE=MERGED \
  bash "$script" --auto 999999 2>"$noauto_stderr")"
noauto_status=$?
if [ "$noauto_status" -eq 0 ] && [ "$noauto_out" = "MERGED" ] \
  && grep -q 'allow_auto_merge=no' "$noauto_stderr"; then
  echo "PASS: --auto + allow_auto_merge=false — skips the --auto attempt entirely, merges immediately"
else
  echo "FAIL: --auto + allow_auto_merge=false — exit=$noauto_status output=${noauto_out:-<empty>}"
  cat "$noauto_stderr"
  failures=$((failures + 1))
fi

# Case 5: --auto + mergeStateStatus=CLEAN (round-3 Critical A / Important B) — must be decided UP
# FRONT from PR state and never attempt `gh pr merge --auto`; merges immediately instead. Note:
# a real GitHub PR in this state would ALSO be correctly handled by round-2's reactive
# clean-status fallback (case 6 below), so this specific case is not expected to go red against
# round-2's code — it verifies the DETERMINISTIC mechanism (I-B) works, not a new failure mode.
alreadyclean_stderr="$mockdir/stderr-alreadyclean.log"
alreadyclean_out="$(PATH="$mockdir:$PATH" MOCK_GH_ALLOW_AUTO_MERGE=true MOCK_GH_MERGE_STATE_STATUS=CLEAN \
  MOCK_GH_AUTO_MODE=clean-status MOCK_GH_STATE=MERGED bash "$script" --auto 999999 2>"$alreadyclean_stderr")"
alreadyclean_status=$?
if [ "$alreadyclean_status" -eq 0 ] && [ "$alreadyclean_out" = "MERGED" ] \
  && grep -q 'mergeStateStatus=CLEAN' "$alreadyclean_stderr"; then
  echo "PASS: --auto + mergeStateStatus=CLEAN — skips the --auto attempt entirely, merges immediately"
else
  echo "FAIL: --auto + mergeStateStatus=CLEAN — exit=$alreadyclean_status output=${alreadyclean_out:-<empty>}"
  cat "$alreadyclean_stderr"
  failures=$((failures + 1))
fi

# Case 6: --auto eligible per the up-front checks, but gh itself still rejects with "clean
# status" (the defensive backstop for the race the up-front check can't close) — falls back to
# an immediate merge rather than hard-failing.
clean_stderr="$mockdir/stderr-clean.log"
clean_out="$(PATH="$mockdir:$PATH" MOCK_GH_ALLOW_AUTO_MERGE=true MOCK_GH_MERGE_STATE_STATUS=BLOCKED \
  MOCK_GH_AUTO_MODE=clean-status MOCK_GH_STATE=MERGED bash "$script" --auto 999999 2>"$clean_stderr")"
clean_status=$?
if [ "$clean_status" -eq 0 ] && [ "$clean_out" = "MERGED" ] && grep -q 'falling back to an immediate merge' "$clean_stderr"; then
  echo "PASS: --auto backstop clean-status rejection — falls back to an immediate merge and prints MERGED"
else
  echo "FAIL: --auto backstop clean-status rejection — exit=$clean_status output=${clean_out:-<empty>}"
  cat "$clean_stderr"
  failures=$((failures + 1))
fi

# Case 7: --auto eligible + merged inside the confirmation window (round-2 Important 1) — state
# flips to MERGED before autoMergeRequest ever shows enabled; must accept MERGED, not error.
window_stderr="$mockdir/stderr-window.log"
window_out="$(PATH="$mockdir:$PATH" MOCK_GH_ALLOW_AUTO_MERGE=true MOCK_GH_MERGE_STATE_STATUS=BLOCKED \
  MOCK_GH_AUTO_MODE=enable MOCK_GH_STATE=MERGED MOCK_GH_AUTOMERGE=null \
  bash "$script" --auto 999999 2>"$window_stderr")"
window_status=$?
if [ "$window_status" -eq 0 ] && [ "$window_out" = "MERGED" ]; then
  echo "PASS: --auto merged-in-window — accepts state=MERGED and prints MERGED, not an error"
else
  echo "FAIL: --auto merged-in-window — exit=$window_status output=${window_out:-<empty>}"
  cat "$window_stderr"
  failures=$((failures + 1))
fi

# Case 8: --auto eligible, but a genuine (non-"clean status") rejection — must exit non-zero and
# must NOT fall back to an immediate merge (MOCK_GH_MERGE_REJECT=1 would make a wrongful
# fallback visible via a DIFFERENT stderr message, proving no fallback occurred).
autoreject_stderr="$mockdir/stderr-autoreject.log"
autoreject_out="$(PATH="$mockdir:$PATH" MOCK_GH_ALLOW_AUTO_MERGE=true MOCK_GH_MERGE_STATE_STATUS=BLOCKED \
  MOCK_GH_AUTO_MODE=reject MOCK_GH_MERGE_REJECT=1 \
  bash "$script" --auto 999999 2>"$autoreject_stderr")"
autoreject_status=$?
if [ "$autoreject_status" -ne 0 ] && [ -z "$autoreject_out" ] \
  && grep -q '^ERROR: gh pr merge .* --auto failed' "$autoreject_stderr" \
  && ! grep -q 'falling back' "$autoreject_stderr"; then
  echo "PASS: --auto genuine rejection — exits non-zero without falling back to an immediate merge"
else
  echo "FAIL: --auto genuine rejection — exit=$autoreject_status output=${autoreject_out:-<empty>}"
  cat "$autoreject_stderr"
  failures=$((failures + 1))
fi

# Case 9: --auto + story-key/done-status together — enforced as an invalid combination (a spec
# PR never completes the story), not merely documented.
badargs_stderr="$mockdir/stderr-badargs.log"
badargs_out="$(PATH="$mockdir:$PATH" bash "$script" --auto 999999 STORY-1 Done 2>"$badargs_stderr")"
badargs_status=$?
if [ "$badargs_status" -ne 0 ] && [ -z "$badargs_out" ] && grep -q '^ERROR: --auto does not accept' "$badargs_stderr"; then
  echo "PASS: --auto + story-key/done-status — rejected as an invalid combination"
else
  echo "FAIL: --auto + story-key/done-status — exit=$badargs_status output=${badargs_out:-<empty>}"
  cat "$badargs_stderr"
  failures=$((failures + 1))
fi

if [ "$failures" -eq 0 ]; then
  echo "PASS: all auto-merge-pr.sh regression cases passed"
  exit 0
else
  echo "FAIL: $failures auto-merge-pr.sh regression case(s) failed"
  exit 1
fi
