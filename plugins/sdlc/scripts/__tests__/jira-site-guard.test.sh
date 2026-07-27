#!/usr/bin/env bash
# jira-site-guard.test.sh — regression test pinning the acli global-active-site defect (NA-77).
#
# acli holds a SINGLE global active site shared across every authenticated Atlassian account. A
# Jira call made while the wrong site is active fails with a PERMISSION-shaped error ("Issue does
# not exist or you do not have permission to see it."), not a site-mismatch-shaped one — and the
# active site has been observed reverting mid-session between two consecutive acli calls. Nothing
# in plugins/sdlc/ re-verifies acli's active site against project-context before a Jira call.
#
# This test pins the CONTRACT for the not-yet-written `jira-site-guard.sh`:
#
#   jira-site-guard.sh [context-file]      (defaults to .claude/project/project-context.md,
#                                            matching the read-review-config.sh convention)
#
#   1. Reads the expected site from the `Jira site` row of <context-file>.
#   2. Reads acli's current active site via `acli jira auth status` (real acli prints
#      "  Site: <site>" — confirmed against the installed acli 1.3.22-stable binary).
#   3. Match                                            -> exit 0, at most one greppable line.
#   4. Differ + an account IS stored for the expected
#      site                                             -> `acli jira auth switch --site <site>`,
#                                                           RE-VERIFY via a second auth status call,
#                                                           exit 0.
#   5. Differ + NO account stored for the expected site -> exit non-zero, message names the
#                                                           expected site AND the
#                                                           `acli jira auth login --site <site>`
#                                                           remedy. Never a silent fallback.
#   6. Context file missing/unreadable, or missing the
#      `Jira site` row                                  -> exit non-zero with a DISTINCT,
#                                                           actionable message per case. Never
#                                                           assume a site.
#   7. Switch reports success (exit 0) but the re-verify status call still shows the wrong site
#      (the observed mid-session reversion) -> exit non-zero. A switch's own exit code is NEVER
#      trusted as proof the site actually changed — this is what makes case 4 a real regression
#      test instead of a mock that always agrees with itself.
#
# Self-runnable, no test harness/framework dependency:
#   bash plugins/sdlc/scripts/__tests__/jira-site-guard.test.sh
# Exit 0 = PASS (all cases), non-zero = FAIL (any case).
#
# `acli` is stubbed via a PATH shim for the entire run: this test must NEVER shell out to the
# real acli binary and must NEVER touch the developer's real global active site.
set -uo pipefail

here="${BASH_SOURCE[0]%/*}"; [ "$here" = "${BASH_SOURCE[0]}" ] && here="."
here="$(cd "$here" && pwd)"
script="$here/../jira-site-guard.sh"

mockdir="$(mktemp -d)"
trap 'rm -rf "$mockdir"' EXIT

# Generic placeholder sites — never this repo's own real Jira site literal (plugins/** ships as a
# published, repo-agnostic artifact; see tools/portability-lint.sh check 1).
EXPECTED_SITE="alpha-corp.atlassian.net"
OTHER_ACTIVE_SITE="beta-corp.atlassian.net"
UNSTORED_SITE="gamma-corp.atlassian.net"

write_fixture() { # $1=path  $2=jira-site-row ("" = omit the row entirely)
  local path="$1" site_row="$2"
  {
    echo "# Project Context"
    echo
    echo "| Token            | Value           |"
    echo "| ---------------- | --------------- |"
    echo "| Project name     | example-project |"
    echo "| Jira project key | EX              |"
    if [ -n "$site_row" ]; then
      echo "| Jira site        | $site_row |"
    fi
    echo "| Base branch      | develop         |"
  } >"$path"
}

# Mock `acli` reproducing the exact contract this guard depends on:
#   - `acli jira auth status`               -> real acli's own output shape:
#                                                "✓ Authenticated" / "  Site: <site>" / ...
#   - `acli jira auth switch --site <site>` -> succeeds (updates the mocked active site) only when
#                                                <site> is in $MOCK_ACLI_STORED_SITES; otherwise
#                                                fails with a login-remedy message on stderr,
#                                                exactly like a real unstored-account switch would.
#   - MOCK_ACLI_SWITCH_NOOP=1                -> switch still exits 0 (reports success) but does NOT
#                                                actually update the mocked active site, reproducing
#                                                the observed mid-session active-site reversion.
# Every call is counted into $MOCK_ACLI_STATE_DIR/status-calls and .../switch-calls so the test can
# assert the guard actually re-verifies after a switch, rather than trusting the switch's own exit
# code (the mock-cli-must-validate-downstream-consumption concern: the re-verify step must consume
# and check the mocked site, not just the prior call's exit status).
cat >"$mockdir/acli" <<'MOCK_ACLI'
#!/usr/bin/env bash
set -uo pipefail
state_dir="${MOCK_ACLI_STATE_DIR:?MOCK_ACLI_STATE_DIR not set}"
site_file="$state_dir/active-site"

case "${1:-}/${2:-}/${3:-}" in
  jira/auth/status)
    echo "call" >> "$state_dir/status-calls"
    site="$(cat "$site_file" 2>/dev/null || echo "")"
    echo "✓ Authenticated"
    echo "  Site: $site"
    echo "  Email: mock@example.com"
    echo "  Authentication Type: oauth"
    exit 0
    ;;
  jira/auth/switch)
    echo "call" >> "$state_dir/switch-calls"
    target=""
    prev=""
    for arg in "$@"; do
      [ "$prev" = "--site" ] && target="$arg"
      prev="$arg"
    done
    stored=" ${MOCK_ACLI_STORED_SITES:-} "
    if [[ "$stored" == *" $target "* ]]; then
      if [ "${MOCK_ACLI_SWITCH_NOOP:-0}" != "1" ]; then
        echo "$target" > "$site_file"
      fi
      echo "Switched active Jira account to $target"
      exit 0
    fi
    echo "Error: no stored acli account for site $target — run: acli jira auth login --site $target" >&2
    exit 1
    ;;
esac
echo "mock acli: unhandled invocation: $*" >&2
exit 1
MOCK_ACLI
chmod +x "$mockdir/acli"

failures=0
statedir=""

new_state() { # sets $statedir to a fresh dir seeded with the given active site
  statedir="$(mktemp -d)"
  printf '%s' "$1" > "$statedir/active-site"
}

call_count() { # $1=state dir  $2=switch-calls|status-calls -> 0 if the mock never wrote it
  local f="$1/$2"
  [ -f "$f" ] || { echo 0; return; }
  wc -l < "$f" | tr -d ' [:space:]'
}

run_guard() { # $1=context-file
  PATH="$mockdir:$PATH" MOCK_ACLI_STATE_DIR="$statedir" \
    MOCK_ACLI_STORED_SITES="${MOCK_ACLI_STORED_SITES:-}" \
    MOCK_ACLI_SWITCH_NOOP="${MOCK_ACLI_SWITCH_NOOP:-0}" \
    bash "$script" "$1"
}

# A genuine guard-authored failure always carries this marker. A bare `bash: .../jira-site-guard.sh:
# No such file or directory` (exit 127, script missing/not-yet-written) does NOT — so asserting this
# marker on every non-zero-exit case is what stops a nonexistent script from trivially passing an
# "exit non-zero + non-empty output" check.
is_guard_error() { # $1=captured stdout+stderr
  printf '%s' "$1" | grep -q '^ERROR: jira-site-guard:'
}

# Case 1: active site already matches expected -> exit 0, no switch issued, minimal output.
ctx1="$mockdir/ctx-match.md"
write_fixture "$ctx1" "$EXPECTED_SITE"
new_state "$EXPECTED_SITE"
out1="$(run_guard "$ctx1" 2>&1)"; status1=$?
lines1="$(printf '%s' "$out1" | grep -c . || true)"
switches1="$(call_count "$statedir" switch-calls)"
if [ "$status1" -eq 0 ] && [ "${switches1:-0}" = "0" ] && [ "${lines1:-0}" -le 1 ]; then
  echo "PASS: site matches -> exit 0, no switch issued, output is at most one line"
else
  echo "FAIL: site matches -> status=$status1 switches=${switches1:-<none>} lines=${lines1:-0}"
  echo "--- guard output ---"; printf '%s\n' "$out1"
  failures=$((failures + 1))
fi
rm -rf "$statedir"

# Case 2: site differs, expected site IS a stored acli account -> switch issued exactly once,
# re-verified (>=2 status calls), exit 0.
ctx2="$mockdir/ctx-differ-stored.md"
write_fixture "$ctx2" "$EXPECTED_SITE"
new_state "$OTHER_ACTIVE_SITE"
out2="$(MOCK_ACLI_STORED_SITES="$EXPECTED_SITE" run_guard "$ctx2" 2>&1)"; status2=$?
switches2="$(call_count "$statedir" switch-calls)"
statuses2="$(call_count "$statedir" status-calls)"
final_site2="$(cat "$statedir/active-site" 2>/dev/null || echo "")"
if [ "$status2" -eq 0 ] && [ "${switches2:-0}" = "1" ] && [ "${statuses2:-0}" -ge 2 ] \
   && [ "$final_site2" = "$EXPECTED_SITE" ]; then
  echo "PASS: site differs + account stored -> switch issued once, re-verified, exit 0"
else
  echo "FAIL: site differs + account stored -> status=$status2 switches=${switches2:-<none>} statuses=${statuses2:-<none>} final_site=$final_site2"
  echo "--- guard output ---"; printf '%s\n' "$out2"
  failures=$((failures + 1))
fi
rm -rf "$statedir"

# Case 3: site differs, NO acli account stored for the expected site -> exit non-zero; message
# names the expected site AND the acli-login remedy. Never a silent fallback, never a
# permission-shaped error (this is the bug's own teeth — see the module header).
ctx3="$mockdir/ctx-differ-unstored.md"
write_fixture "$ctx3" "$UNSTORED_SITE"
new_state "$OTHER_ACTIVE_SITE"
out3="$(MOCK_ACLI_STORED_SITES="$EXPECTED_SITE" run_guard "$ctx3" 2>&1)"; status3=$?
if [ "$status3" -ne 0 ] && is_guard_error "$out3" && printf '%s' "$out3" | grep -qF "$UNSTORED_SITE" \
   && printf '%s' "$out3" | grep -q 'acli jira auth login'; then
  echo "PASS: site differs + no stored account -> exit non-zero, names site + login remedy"
else
  echo "FAIL: site differs + no stored account -> status=$status3"
  echo "--- guard output ---"; printf '%s\n' "$out3"
  failures=$((failures + 1))
fi
rm -rf "$statedir"

# Case 4: context file missing entirely -> exit non-zero, actionable + distinct message.
ctx4="$mockdir/does-not-exist.md"
new_state "$EXPECTED_SITE"
out4="$(run_guard "$ctx4" 2>&1)"; status4=$?
if [ "$status4" -ne 0 ] && is_guard_error "$out4" && printf '%s' "$out4" | grep -qF "$ctx4"; then
  echo "PASS: missing context file -> exit non-zero with a guard-authored message naming the path"
else
  echo "FAIL: missing context file -> status=$status4 output=${out4:-<empty>}"
  failures=$((failures + 1))
fi
rm -rf "$statedir"

# Case 5: context file exists but has no `Jira site` row -> exit non-zero, and the message must be
# DISTINCT from case 4's (missing-file vs missing-row are different failure modes; conflating them
# would leave a user chasing the wrong fix).
ctx5="$mockdir/ctx-no-site-row.md"
write_fixture "$ctx5" ""
new_state "$EXPECTED_SITE"
out5="$(run_guard "$ctx5" 2>&1)"; status5=$?
if [ "$status5" -ne 0 ] && is_guard_error "$out5" && [ "$out5" != "$out4" ]; then
  echo "PASS: missing 'Jira site' row -> exit non-zero, message distinct from missing-file case"
else
  echo "FAIL: missing 'Jira site' row -> status=$status5 output=${out5:-<empty>} (vs missing-file output=${out4:-<empty>})"
  failures=$((failures + 1))
fi
rm -rf "$statedir"

# Case 6: switch reports success (exit 0) but the re-verify status call still shows the WRONG
# site (the observed mid-session active-site reversion) -> exit non-zero. Never a false pass.
ctx6="$mockdir/ctx-reverify-fails.md"
write_fixture "$ctx6" "$EXPECTED_SITE"
new_state "$OTHER_ACTIVE_SITE"
out6="$(MOCK_ACLI_STORED_SITES="$EXPECTED_SITE" MOCK_ACLI_SWITCH_NOOP=1 run_guard "$ctx6" 2>&1)"; status6=$?
switches6="$(call_count "$statedir" switch-calls)"
if [ "$status6" -ne 0 ] && is_guard_error "$out6" && [ "${switches6:-0}" = "1" ]; then
  echo "PASS: switch succeeds but re-verify still shows wrong site -> exit non-zero (no false pass)"
else
  echo "FAIL: switch succeeds but re-verify still shows wrong site -> status=$status6 switches=${switches6:-<none>}"
  echo "--- guard output ---"; printf '%s\n' "$out6"
  failures=$((failures + 1))
fi
rm -rf "$statedir"

if [ "$failures" -eq 0 ]; then
  echo "PASS: all jira-site-guard.sh regression cases passed"
  exit 0
else
  echo "FAIL: $failures jira-site-guard.sh regression case(s) failed"
  exit 1
fi
