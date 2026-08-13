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
#   3. `--auto` eligible (`allow_auto_merge=true`, not yet clean) + enable — armed but not yet
#      merged: prints AUTO-MERGE-ENABLED, exit 0.
#   4. `--auto` + `allow_auto_merge=false` + NOT clean (the real GitHub-default configuration) —
#      waits for checks to settle (NA-104 founder-directed fix: round-4 made this refuse outright,
#      which was itself a regression — Full Auto stalling forever on the default repo config),
#      then merges once they do.
#   5. `--auto` + `allow_auto_merge=false` + `mergeStateStatus=CLEAN` — also routes through the
#      checks wait (an initial CLEAN can be a false-CLEAN before CI registers any check) rather
#      than merging on CLEAN alone.
#   6. `--auto` + `mergeStateStatus=CLEAN` with `allow_auto_merge=true` too (NA-104 round-3
#      Critical A) — decided UP FRONT from PR state, never attempts `gh pr merge --auto`; also
#      routes through the checks wait rather than merging on CLEAN alone.
#   7. `--auto` eligible per the up-front checks, but `gh pr merge --auto` itself still rejects
#      with "clean status" (defensive backstop for the race the up-front check can't close) —
#      falls back to an immediate merge instead of hard-failing.
#   8. `--auto` + merged inside the confirmation window (NA-104 round-2 Important 1) — accepts
#      `state == MERGED` as success instead of erroring because `autoMergeRequest` is null.
#   9. `--auto` eligible, but a genuine (non-"clean status") rejection — exits non-zero, does NOT
#      fall back.
#  10. `--auto` + `allow_auto_merge=true` + `mergeStateStatus=UNKNOWN` (common seconds after a PR
#      is raised, while GitHub is still computing mergeability) — arms `--auto` same as case 3;
#      UNKNOWN must never be treated as CLEAN.
#  11. `--auto` + story-key/done-status together — rejected as an invalid combination (a spec PR
#      never completes the story), enforced rather than merely documented.
#  12. `--auto`, non-arming path, checks pending then settle passing — waits, then merges.
#  13. `--auto`, non-arming path, a check is failing — refuses, exit 1, no merge call.
#  14. `--auto`, non-arming path, no checks configured at all — merges once mergeable.
#  15. `--auto`, non-arming path, checks pending forever — bounded timeout, exit 3, PR stays open.
#  16. `--auto` waits on a PENDING NON-REQUIRED check instead of treating it as none (regression
#      pin: `gh pr checks --required` returns `[]` on an unprotected branch/no required checks —
#      exactly this repo's own configuration — which would silently skip the wait).
#  17. `--auto`, non-arming path, the `gh pr checks` query itself keeps failing (network/auth/
#      rate-limit/5xx) — must NOT be read as "no checks" and must NOT merge; retries within the
#      poll/timeout budget and exits 3 (transient, same code as case 15) once the budget is spent
#      (NA-104 review round Critical 1).
#  18. `--auto`, non-arming path, the first `gh pr checks` read comes back `[]` and only a later
#      read reports a real (passing) check — must NOT treat the first empty read as authoritative
#      and merge immediately; must wait through the none-grace window and merge once the real
#      check settles (NA-104 review round Critical 2).
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
#   - `gh pr checks <pr> --json bucket,name`                  -> behaviour selected by
#                                                                MOCK_GH_CHECKS_MODE (none |
#                                                                fail | pending-forever |
#                                                                pending-then-pass |
#                                                                nonrequired-pending-then-pass |
#                                                                fail-query | empty-then-pass;
#                                                                default none). pending-then-pass
#                                                                counts calls via
#                                                                MOCK_GH_CHECKS_COUNTER_FILE and
#                                                                flips to passing on call number
#                                                                MOCK_GH_CHECKS_PASS_AFTER (default
#                                                                2). nonrequired-pending-then-pass
#                                                                is the same sequence but returns
#                                                                `[]` if the caller still passes
#                                                                `--required` (regression pin —
#                                                                the script must NOT pass it).
#                                                                fail-query always exits 1 with no
#                                                                valid JSON on stdout (Critical 1
#                                                                pin — a persistently failing gh
#                                                                call must never be read as "no
#                                                                checks"). empty-then-pass is
#                                                                counter-file-driven like
#                                                                pending-then-pass but returns `[]`
#                                                                (not a pending bucket) for the
#                                                                first N-1 calls, then a real
#                                                                passing check (Critical 2 pin — a
#                                                                single early `[]` read must not be
#                                                                treated as authoritative).
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
      checks)
        case "${MOCK_GH_CHECKS_MODE:-none}" in
          none) echo '[]' ;;
          fail) echo '[{"bucket":"fail","name":"ci-main"}]' ;;
          pending-forever) echo '[{"bucket":"pending","name":"ci-main"}]' ;;
          pending-then-pass)
            counter_file="${MOCK_GH_CHECKS_COUNTER_FILE:?}"
            count=0
            [ -f "$counter_file" ] && count="$(cat "$counter_file")"
            count=$((count + 1))
            echo "$count" > "$counter_file"
            if [ "$count" -lt "${MOCK_GH_CHECKS_PASS_AFTER:-2}" ]; then
              echo '[{"bucket":"pending","name":"ci-main"}]'
            else
              echo '[{"bucket":"pass","name":"ci-main"}]'
            fi
            ;;
          nonrequired-pending-then-pass)
            has_required=0
            for arg in "$@"; do [ "$arg" = "--required" ] && has_required=1; done
            if [ "$has_required" = 1 ]; then
              echo '[]'
            else
              counter_file="${MOCK_GH_CHECKS_COUNTER_FILE:?}"
              count=0
              [ -f "$counter_file" ] && count="$(cat "$counter_file")"
              count=$((count + 1))
              echo "$count" > "$counter_file"
              if [ "$count" -lt "${MOCK_GH_CHECKS_PASS_AFTER:-2}" ]; then
                echo '[{"bucket":"pending","name":"ci-nonrequired"}]'
              else
                echo '[{"bucket":"pass","name":"ci-nonrequired"}]'
              fi
            fi
            ;;
          fail-query)
            echo "gh: unexpected end of JSON input (or similar transient API failure)" >&2
            exit 1
            ;;
          empty-then-pass)
            counter_file="${MOCK_GH_CHECKS_COUNTER_FILE:?}"
            count=0
            [ -f "$counter_file" ] && count="$(cat "$counter_file")"
            count=$((count + 1))
            echo "$count" > "$counter_file"
            if [ "$count" -lt "${MOCK_GH_CHECKS_PASS_AFTER:-2}" ]; then
              echo '[]'
            else
              echo '[{"bucket":"pass","name":"ci-main"}]'
            fi
            ;;
        esac
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

# Case 4: --auto + allow_auto_merge=false + NOT clean (the real GitHub default: allow_auto_merge
# =false AND a fresh PR's checks still pending/computing). Superseded from round-4's "must
# REFUSE" — that refusal was itself the regression this round fixes (Full Auto stalling forever
# on the default GitHub configuration). Must now WAIT for checks and merge once they settle,
# never merging blind (MOCK_GH_CHECKS_MODE default `none` here — no checks reported at all — so
# it settles immediately).
noauto_stderr="$mockdir/stderr-noauto.log"
noauto_out="$(PATH="$mockdir:$PATH" MOCK_GH_ALLOW_AUTO_MERGE=false MOCK_GH_MERGE_STATE_STATUS=BLOCKED \
  MOCK_GH_AUTO_MODE=reject MOCK_GH_STATE=MERGED AUTO_MERGE_CHECKS_NONE_GRACE_SECS=0 \
  bash "$script" --auto 999999 2>"$noauto_stderr")"
noauto_status=$?
if [ "$noauto_status" -eq 0 ] && [ "$noauto_out" = "MERGED" ] \
  && grep -q 'has reported no checks' "$noauto_stderr"; then
  echo "PASS: --auto + allow_auto_merge=false + not clean — waits for checks, then merges"
else
  echo "FAIL: --auto + allow_auto_merge=false + not clean — exit=$noauto_status output=${noauto_out:-<empty>}"
  cat "$noauto_stderr"
  failures=$((failures + 1))
fi

# Case 5: --auto + allow_auto_merge=false + mergeStateStatus=CLEAN — still routes through the
# checks wait (an initial CLEAN can be a false-CLEAN before CI registers), which settles
# immediately here (MOCK_GH_CHECKS_MODE default `none`) and merges.
falseclean_stderr="$mockdir/stderr-falseclean.log"
falseclean_out="$(PATH="$mockdir:$PATH" MOCK_GH_ALLOW_AUTO_MERGE=false MOCK_GH_MERGE_STATE_STATUS=CLEAN \
  MOCK_GH_AUTO_MODE=reject MOCK_GH_STATE=MERGED AUTO_MERGE_CHECKS_NONE_GRACE_SECS=0 \
  bash "$script" --auto 999999 2>"$falseclean_stderr")"
falseclean_status=$?
if [ "$falseclean_status" -eq 0 ] && [ "$falseclean_out" = "MERGED" ] \
  && grep -q 'has reported no checks' "$falseclean_stderr"; then
  echo "PASS: --auto + allow_auto_merge=false + mergeStateStatus=CLEAN — waits for checks, then merges"
else
  echo "FAIL: --auto + allow_auto_merge=false + mergeStateStatus=CLEAN — exit=$falseclean_status output=${falseclean_out:-<empty>}"
  cat "$falseclean_stderr"
  failures=$((failures + 1))
fi

# Case 6: --auto + mergeStateStatus=CLEAN with allow_auto_merge=true too (round-3 Critical A) —
# must be decided UP FRONT from PR state and never attempt `gh pr merge --auto`; routes through
# the checks wait (settles immediately, MOCK_GH_CHECKS_MODE default `none`) and merges instead of
# assuming CLEAN alone is enough to skip straight to a merge attempt.
alreadyclean_stderr="$mockdir/stderr-alreadyclean.log"
alreadyclean_out="$(PATH="$mockdir:$PATH" MOCK_GH_ALLOW_AUTO_MERGE=true MOCK_GH_MERGE_STATE_STATUS=CLEAN \
  MOCK_GH_AUTO_MODE=clean-status MOCK_GH_STATE=MERGED AUTO_MERGE_CHECKS_NONE_GRACE_SECS=0 \
  bash "$script" --auto 999999 2>"$alreadyclean_stderr")"
alreadyclean_status=$?
if [ "$alreadyclean_status" -eq 0 ] && [ "$alreadyclean_out" = "MERGED" ] \
  && grep -q 'has reported no checks' "$alreadyclean_stderr"; then
  echo "PASS: --auto + mergeStateStatus=CLEAN — skips the --auto attempt entirely, waits for checks, then merges"
else
  echo "FAIL: --auto + mergeStateStatus=CLEAN — exit=$alreadyclean_status output=${alreadyclean_out:-<empty>}"
  cat "$alreadyclean_stderr"
  failures=$((failures + 1))
fi

# Case 7: --auto eligible per the up-front checks, but gh itself still rejects with "clean
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

# Case 8: --auto eligible + merged inside the confirmation window (round-2 Important 1) — state
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

# Case 9: --auto eligible, but a genuine (non-"clean status") rejection — must exit non-zero and
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

# Case 10: --auto + allow_auto_merge=true + mergeStateStatus=UNKNOWN (round-4 Important 1 —
# common seconds after a PR is raised, while GitHub is still computing mergeability). UNKNOWN
# must arm --auto exactly like BLOCKED (case 3), never be treated as CLEAN and merged
# immediately, and never trip the new allow_auto_merge=false refusal path (case 4) either.
unknown_stderr="$mockdir/stderr-unknown.log"
unknown_out="$(PATH="$mockdir:$PATH" MOCK_GH_ALLOW_AUTO_MERGE=true MOCK_GH_MERGE_STATE_STATUS=UNKNOWN \
  MOCK_GH_AUTO_MODE=enable MOCK_GH_STATE=OPEN MOCK_GH_AUTOMERGE=true \
  bash "$script" --auto 999999 2>"$unknown_stderr")"
unknown_status=$?
if [ "$unknown_status" -eq 0 ] && [ "$unknown_out" = "AUTO-MERGE-ENABLED" ]; then
  echo "PASS: --auto + mergeStateStatus=UNKNOWN — arms auto-merge, same as any other non-CLEAN state"
else
  echo "FAIL: --auto + mergeStateStatus=UNKNOWN — exit=$unknown_status output=${unknown_out:-<empty>}"
  cat "$unknown_stderr"
  failures=$((failures + 1))
fi

# Case 11: --auto + story-key/done-status together — enforced as an invalid combination (a spec
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

# Case 12: --auto, non-arming path, checks start pending then settle passing — must wait (not
# merge on the first pending read, not time out) and merge once they go green.
pendingpass_stderr="$mockdir/stderr-pendingpass.log"
pendingpass_counter="$mockdir/checks-counter-pendingpass"
pendingpass_out="$(PATH="$mockdir:$PATH" MOCK_GH_ALLOW_AUTO_MERGE=false MOCK_GH_MERGE_STATE_STATUS=BLOCKED \
  MOCK_GH_CHECKS_MODE=pending-then-pass MOCK_GH_CHECKS_COUNTER_FILE="$pendingpass_counter" MOCK_GH_CHECKS_PASS_AFTER=2 \
  AUTO_MERGE_CHECKS_POLL_SECS=1 AUTO_MERGE_CHECKS_TIMEOUT_SECS=30 \
  bash "$script" --auto 999999 2>"$pendingpass_stderr")"
pendingpass_status=$?
if [ "$pendingpass_status" -eq 0 ] && [ "$pendingpass_out" = "MERGED" ] \
  && grep -q 'checks all settled and passing' "$pendingpass_stderr"; then
  echo "PASS: --auto checks-pending-then-green — waits, then merges once passing"
else
  echo "FAIL: --auto checks-pending-then-green — exit=$pendingpass_status output=${pendingpass_out:-<empty>}"
  cat "$pendingpass_stderr"
  failures=$((failures + 1))
fi

# Case 13: --auto, non-arming path, a check is failing — must refuse with exit 1
# SPECIFICALLY (not exit 3, which means timeout — auto.md's caller distinguishes "fix CI" from
# "just wait and re-run" by this exact code) and MUST NOT call `gh pr merge` at all
# (MOCK_GH_MERGE_REJECT=1 would surface a DIFFERENT stderr message if the script wrongly
# attempted the merge call anyway, proving it didn't).
checkfail_stderr="$mockdir/stderr-checkfail.log"
checkfail_out="$(PATH="$mockdir:$PATH" MOCK_GH_ALLOW_AUTO_MERGE=false MOCK_GH_MERGE_STATE_STATUS=BLOCKED \
  MOCK_GH_CHECKS_MODE=fail MOCK_GH_MERGE_REJECT=1 \
  bash "$script" --auto 999999 2>"$checkfail_stderr")"
checkfail_status=$?
if [ "$checkfail_status" -eq 1 ] && [ -z "$checkfail_out" ] \
  && grep -q '^ERROR: PR 999999 has failing check(s): ci-main' "$checkfail_stderr" \
  && ! grep -q '^merged:' "$checkfail_stderr"; then
  echo "PASS: --auto check-failing — refuses, exit 1, names the failing check, no merge call"
else
  echo "FAIL: --auto check-failing — exit=$checkfail_status output=${checkfail_out:-<empty>}"
  cat "$checkfail_stderr"
  failures=$((failures + 1))
fi

# Case 14: --auto, non-arming path, no checks configured at all (explicit MOCK_GH_CHECKS_MODE, not
# relying on the default) — must merge once mergeable, not stall waiting for checks that will
# never appear.
nochecks_stderr="$mockdir/stderr-nochecks.log"
nochecks_out="$(PATH="$mockdir:$PATH" MOCK_GH_ALLOW_AUTO_MERGE=false MOCK_GH_MERGE_STATE_STATUS=BLOCKED \
  MOCK_GH_CHECKS_MODE=none AUTO_MERGE_CHECKS_NONE_GRACE_SECS=0 \
  bash "$script" --auto 999999 2>"$nochecks_stderr")"
nochecks_status=$?
if [ "$nochecks_status" -eq 0 ] && [ "$nochecks_out" = "MERGED" ] \
  && grep -q 'has reported no checks' "$nochecks_stderr"; then
  echo "PASS: --auto no-checks-configured — merges once mergeable"
else
  echo "FAIL: --auto no-checks-configured — exit=$nochecks_status output=${nochecks_out:-<empty>}"
  cat "$nochecks_stderr"
  failures=$((failures + 1))
fi

# Case 15: --auto, non-arming path, checks pending forever — must time out (bounded, never wait
# unbounded) and exit 3 SPECIFICALLY (distinct from exit 1 — see case 13) leaving the PR open,
# not merge blind.
timeout_stderr="$mockdir/stderr-timeout.log"
timeout_out="$(PATH="$mockdir:$PATH" MOCK_GH_ALLOW_AUTO_MERGE=false MOCK_GH_MERGE_STATE_STATUS=BLOCKED \
  MOCK_GH_CHECKS_MODE=pending-forever AUTO_MERGE_CHECKS_TIMEOUT_SECS=1 AUTO_MERGE_CHECKS_POLL_SECS=1 \
  bash "$script" --auto 999999 2>"$timeout_stderr")"
timeout_status=$?
if [ "$timeout_status" -eq 3 ] && [ -z "$timeout_out" ] \
  && grep -q '^ERROR: PR 999999 checks did not settle within 1s' "$timeout_stderr"; then
  echo "PASS: --auto checks-pending timeout — exits 3, leaves the PR open, never waits unbounded"
else
  echo "FAIL: --auto checks-pending timeout — exit=$timeout_status output=${timeout_out:-<empty>}"
  cat "$timeout_stderr"
  failures=$((failures + 1))
fi

# Case 16 (regression pin): a PR with a PENDING NON-REQUIRED check must be waited on, not treated
# as "no checks". The mock returns `[]` when called WITH `--required` (matching this repo's own
# `gh pr checks --required` -> `[]`, since develop has no branch protection) and the real
# pending-then-pass sequence when called WITHOUT it — so a script that still passes `--required`
# would wrongly see `[]` on the first call and merge immediately reporting "no checks reported"
# instead of waiting for ci-nonrequired to settle.
nonreq_stderr="$mockdir/stderr-nonreq.log"
nonreq_counter="$mockdir/checks-counter-nonreq"
nonreq_out="$(PATH="$mockdir:$PATH" MOCK_GH_ALLOW_AUTO_MERGE=false MOCK_GH_MERGE_STATE_STATUS=BLOCKED \
  MOCK_GH_CHECKS_MODE=nonrequired-pending-then-pass MOCK_GH_CHECKS_COUNTER_FILE="$nonreq_counter" MOCK_GH_CHECKS_PASS_AFTER=2 \
  AUTO_MERGE_CHECKS_POLL_SECS=1 AUTO_MERGE_CHECKS_TIMEOUT_SECS=30 \
  bash "$script" --auto 999999 2>"$nonreq_stderr")"
nonreq_status=$?
if [ "$nonreq_status" -eq 0 ] && [ "$nonreq_out" = "MERGED" ] \
  && grep -q 'checks all settled and passing' "$nonreq_stderr" \
  && ! grep -q 'has reported no checks' "$nonreq_stderr"; then
  echo "PASS: --auto waits on a pending non-required check instead of treating it as none"
else
  echo "FAIL: --auto waits on a pending non-required check — exit=$nonreq_status output=${nonreq_out:-<empty>}"
  cat "$nonreq_stderr"
  failures=$((failures + 1))
fi

# Case 17 (NA-104 review round Critical 1): the `gh pr checks` query itself keeps failing (mock:
# fail-query — exit 1, no valid JSON) — must NOT be silently read as "no checks" and merged. Must
# retry within the poll/timeout budget and, once the budget is spent, exit 3 (transient — same
# code as the pending-forever timeout in case 15) with a message distinguishing a failing QUERY
# from a failing CHECK, and never call `gh pr merge` at all (MOCK_GH_MERGE_REJECT=1 would surface
# a different stderr message if the script wrongly attempted the merge anyway, proving it didn't).
queryfail_stderr="$mockdir/stderr-queryfail.log"
queryfail_out="$(PATH="$mockdir:$PATH" MOCK_GH_ALLOW_AUTO_MERGE=false MOCK_GH_MERGE_STATE_STATUS=BLOCKED \
  MOCK_GH_CHECKS_MODE=fail-query MOCK_GH_MERGE_REJECT=1 \
  AUTO_MERGE_CHECKS_TIMEOUT_SECS=1 AUTO_MERGE_CHECKS_POLL_SECS=1 \
  bash "$script" --auto 999999 2>"$queryfail_stderr")"
queryfail_status=$?
if [ "$queryfail_status" -eq 3 ] && [ -z "$queryfail_out" ] \
  && grep -q 'gh pr checks query failed' "$queryfail_stderr" \
  && grep -q '^ERROR: PR 999999 checks did not settle within 1s' "$queryfail_stderr" \
  && ! grep -q 'has failing check' "$queryfail_stderr" \
  && ! grep -q '^merged:' "$queryfail_stderr"; then
  echo "PASS: --auto gh-checks-query-fails — does NOT merge, retries, exits 3 (transient) once the budget is spent"
else
  echo "FAIL: --auto gh-checks-query-fails — exit=$queryfail_status output=${queryfail_out:-<empty>}"
  cat "$queryfail_stderr"
  failures=$((failures + 1))
fi

# Case 18 (NA-104 review round Critical 2): the first `gh pr checks` read comes back `[]`, and only
# a LATER read reports a real (passing) check (mock: empty-then-pass, counter-driven). The first
# empty read must NOT be treated as authoritative "no checks" and short-circuit into an immediate
# merge — the script must keep waiting and merge once the real check settles, and must never emit
# the "has reported no checks" message (which would prove it wrongly concluded "none" from the
# first read alone).
emptypass_stderr="$mockdir/stderr-emptypass.log"
emptypass_counter="$mockdir/checks-counter-emptypass"
emptypass_out="$(PATH="$mockdir:$PATH" MOCK_GH_ALLOW_AUTO_MERGE=false MOCK_GH_MERGE_STATE_STATUS=BLOCKED \
  MOCK_GH_CHECKS_MODE=empty-then-pass MOCK_GH_CHECKS_COUNTER_FILE="$emptypass_counter" MOCK_GH_CHECKS_PASS_AFTER=2 \
  AUTO_MERGE_CHECKS_POLL_SECS=1 AUTO_MERGE_CHECKS_TIMEOUT_SECS=30 AUTO_MERGE_CHECKS_NONE_GRACE_SECS=5 \
  bash "$script" --auto 999999 2>"$emptypass_stderr")"
emptypass_status=$?
if [ "$emptypass_status" -eq 0 ] && [ "$emptypass_out" = "MERGED" ] \
  && grep -q 'checks all settled and passing' "$emptypass_stderr" \
  && ! grep -q 'has reported no checks' "$emptypass_stderr"; then
  echo "PASS: --auto empty-check-read-then-real-check — does not treat a single [] read as authoritative, waits then merges"
else
  echo "FAIL: --auto empty-check-read-then-real-check — exit=$emptypass_status output=${emptypass_out:-<empty>}"
  cat "$emptypass_stderr"
  failures=$((failures + 1))
fi

if [ "$failures" -eq 0 ]; then
  echo "PASS: all auto-merge-pr.sh regression cases passed"
  exit 0
else
  echo "FAIL: $failures auto-merge-pr.sh regression case(s) failed"
  exit 1
fi
