#!/usr/bin/env bash
# resolve-ai-workflow-mode.test.sh — ladder-rung + label-precedence + error-row coverage
# for resolve-ai-workflow-mode.sh (NA-86 A6). Stubs `acli` on PATH.
#
# Self-runnable, no test harness/framework dependency:
#   bash plugins/sdlc/scripts/__tests__/resolve-ai-workflow-mode.test.sh
# Exit 0 = PASS (all cases), non-zero = FAIL (any case).
set -uo pipefail

here="${BASH_SOURCE[0]%/*}"; [ "$here" = "${BASH_SOURCE[0]}" ] && here="."
script="$(cd "$here/.." && pwd)/resolve-ai-workflow-mode.sh"

failures=0
mockdir="$(mktemp -d)"
trap 'rm -rf "$mockdir"' EXIT

fail() { echo "FAIL: $1" >&2; failures=$((failures + 1)); }
pass() { echo "PASS: $1"; }

get_field() { # $1=output $2=key
  printf '%s\n' "$1" | sed -n "s/^$2=//p" | head -1
}

# Write a mock `acli` driven entirely by env vars, so each case can select a scenario
# without regenerating the mock script. jq is the real binary (available in this repo's
# toolchain) so resolve-ai-workflow-mode.sh's own jq expression actually runs.
cat > "$mockdir/acli" <<'MOCK_ACLI'
#!/usr/bin/env bash
set -uo pipefail
SCENARIO="${MOCK_SCENARIO:-none}"

case "$SCENARIO" in
  field-full-auto)
    if [ "$1 $2 $3" = "jira workitem search" ]; then
      for a in "$@"; do
        case "$a" in *'"AI Workflow" = "Full Auto"'*) echo '{"key":"KEY-1"}'; exit 0 ;; esac
      done
      exit 0
    fi
    ;;
  field-set-readable)
    if [ "$1 $2 $3" = "jira workitem search" ]; then
      for a in "$@"; do
        case "$a" in
          *'"AI Workflow" = "Full Auto"'*) exit 0 ;;  # no match
          *'"AI Workflow" is not EMPTY'*) echo '{"key":"KEY-1"}'; exit 0 ;;
        esac
      done
      exit 0
    fi
    if [ "$1 $2 $3" = "jira workitem view" ]; then
      echo '{"fields":{"AI Workflow":{"value":"Auto"}}}'
      exit 0
    fi
    ;;
  field-set-unreadable)
    if [ "$1 $2 $3" = "jira workitem search" ]; then
      for a in "$@"; do
        case "$a" in
          *'"AI Workflow" = "Full Auto"'*) exit 0 ;;
          *'"AI Workflow" is not EMPTY'*) echo '{"key":"KEY-1"}'; exit 0 ;;
        esac
      done
      exit 0
    fi
    if [ "$1 $2 $3" = "jira workitem view" ]; then
      echo '{"fields":{}}'
      exit 0
    fi
    ;;
  label-assisted|label-auto|label-full-auto)
    if [ "$1 $2 $3" = "jira workitem search" ]; then
      for a in "$@"; do
        case "$a" in *'"AI Workflow"'*) exit 0 ;; esac  # field rungs: no match
      done
      target=""
      case "$SCENARIO" in
        label-assisted) target='labels = "AI-Workflow:assisted"' ;;
        label-auto) target='labels = "AI-Workflow:auto"' ;;
        label-full-auto) target='labels = "AI-Workflow:full-auto"' ;;
      esac
      for a in "$@"; do
        case "$a" in *"$target"*) echo '{"key":"KEY-1"}'; exit 0 ;; esac
      done
      exit 0
    fi
    ;;
  label-precedence-multi)
    # Both assisted and auto labels present — assisted must win (most conservative first).
    if [ "$1 $2 $3" = "jira workitem search" ]; then
      for a in "$@"; do
        case "$a" in *'"AI Workflow"'*) exit 0 ;; esac
      done
      for a in "$@"; do
        case "$a" in
          *'labels = "AI-Workflow:assisted"'*) echo '{"key":"KEY-1"}'; exit 0 ;;
          *'labels = "AI-Workflow:auto"'*) echo '{"key":"KEY-1"}'; exit 0 ;;
        esac
      done
      exit 0
    fi
    ;;
  none)
    if [ "$1 $2 $3" = "jira workitem search" ]; then exit 0; fi
    ;;
  all-error)
    exit 1
    ;;
  rung2-transient-then-success)
    # Rung-2 "is not EMPTY" probe: acli errors on attempts 1-2 (transient), succeeds on
    # attempt 3 -> the real value is then read via `jira workitem view`.
    if [ "$1 $2 $3" = "jira workitem search" ]; then
      for a in "$@"; do
        case "$a" in *'"AI Workflow" = "Full Auto"'*) exit 0 ;; esac  # rung 1: no match
      done
      for a in "$@"; do
        case "$a" in
          *'"AI Workflow" is not EMPTY'*)
            n=0
            [ -f "$MOCK_COUNTER_FILE" ] && n="$(cat "$MOCK_COUNTER_FILE")"
            n=$((n + 1))
            printf '%s' "$n" > "$MOCK_COUNTER_FILE"
            if [ "$n" -lt 3 ]; then exit 1; fi  # simulated transient acli error
            echo '{"key":"KEY-1"}'; exit 0
            ;;
        esac
      done
      exit 0
    fi
    if [ "$1 $2 $3" = "jira workitem view" ]; then
      echo '{"fields":{"AI Workflow":{"value":"Assisted"}}}'
      exit 0
    fi
    ;;
  rung2-persistent-error)
    # Rung-2 "is not EMPTY" probe: acli errors on all 3 attempts -> inconclusive ->
    # falls through to the label rungs, which also don't match -> MODE=""/none.
    if [ "$1 $2 $3" = "jira workitem search" ]; then
      for a in "$@"; do
        case "$a" in *'"AI Workflow" = "Full Auto"'*) exit 0 ;; esac  # rung 1: no match
      done
      for a in "$@"; do
        case "$a" in
          *'"AI Workflow" is not EMPTY'*)
            n=0
            [ -f "$MOCK_COUNTER_FILE" ] && n="$(cat "$MOCK_COUNTER_FILE")"
            n=$((n + 1))
            printf '%s' "$n" > "$MOCK_COUNTER_FILE"
            exit 1  # simulated persistent acli error
            ;;
        esac
      done
      exit 0  # label rungs: no match either
    fi
    ;;
  rung2-clean-empty-no-retry)
    # Rung-2 "is not EMPTY" probe: acli succeeds but the field is genuinely unset (clean
    # empty result) -> must NOT retry, must fall straight through to the label rungs.
    if [ "$1 $2 $3" = "jira workitem search" ]; then
      for a in "$@"; do
        case "$a" in *'"AI Workflow" = "Full Auto"'*) exit 0 ;; esac  # rung 1: no match
      done
      for a in "$@"; do
        case "$a" in
          *'"AI Workflow" is not EMPTY'*)
            n=0
            [ -f "$MOCK_COUNTER_FILE" ] && n="$(cat "$MOCK_COUNTER_FILE")"
            n=$((n + 1))
            printf '%s' "$n" > "$MOCK_COUNTER_FILE"
            exit 0  # clean call, no output -> no match, not an error
            ;;
        esac
      done
      exit 0  # label rungs: no match either
    fi
    ;;
esac
exit 0
MOCK_ACLI
chmod +x "$mockdir/acli"

run_case() { # $1=scenario $2=issue-key
  # RETRY_SLEEP_SECS=0 keeps the rung-2 retry loop's back-off from slowing this test down —
  # the loop's decision logic is exercised regardless of the sleep duration.
  MOCK_SCENARIO="$1" RETRY_SLEEP_SECS=0 PATH="$mockdir:$PATH" bash "$script" "$2"
}

run_case_counted() { # $1=scenario $2=issue-key $3=counter-file -> sets $out, counter is at $3
  rm -f "$3"
  MOCK_SCENARIO="$1" RETRY_SLEEP_SECS=0 MOCK_COUNTER_FILE="$3" PATH="$mockdir:$PATH" bash "$script" "$2"
}

# --- Rung 1: field = Full Auto -------------------------------------------------------
out="$(run_case field-full-auto KEY-1)"
mode="$(get_field "$out" MODE)"; src="$(get_field "$out" MODE_SOURCE)"
[ "$mode" = "Full Auto" ] && [ "$src" = "field" ] \
  && pass "rung 1: field=Full Auto -> MODE=Full Auto, MODE_SOURCE=field" \
  || fail "rung 1 — got MODE=$mode MODE_SOURCE=$src"

# --- Rung 2: field set, not Full Auto, readable --------------------------------------
out="$(run_case field-set-readable KEY-1)"
mode="$(get_field "$out" MODE)"; src="$(get_field "$out" MODE_SOURCE)"
[ "$mode" = "Auto" ] && [ "$src" = "field" ] \
  && pass "rung 2: field set + readable -> MODE=Auto, MODE_SOURCE=field" \
  || fail "rung 2 (readable) — got MODE=$mode MODE_SOURCE=$src"

# --- Rung 2: field set but unreadable (default-unreadable row) ----------------------
out="$(run_case field-set-unreadable KEY-1)"
mode="$(get_field "$out" MODE)"; src="$(get_field "$out" MODE_SOURCE)"
[ "$mode" = "Auto" ] && [ "$src" = "default-unreadable" ] \
  && pass "rung 2: field set + unreadable -> MODE=Auto, MODE_SOURCE=default-unreadable" \
  || fail "rung 2 (unreadable) — got MODE=$mode MODE_SOURCE=$src"

# --- Rung 3: labels, each token -------------------------------------------------------
out="$(run_case label-assisted KEY-1)"
mode="$(get_field "$out" MODE)"; src="$(get_field "$out" MODE_SOURCE)"
[ "$mode" = "Assisted" ] && [ "$src" = "label" ] \
  && pass "rung 3: AI-Workflow:assisted -> MODE=Assisted" \
  || fail "rung 3 (assisted) — got MODE=$mode MODE_SOURCE=$src"

out="$(run_case label-auto KEY-1)"
mode="$(get_field "$out" MODE)"
[ "$mode" = "Auto" ] && pass "rung 3: AI-Workflow:auto -> MODE=Auto" \
  || fail "rung 3 (auto) — got MODE=$mode"

out="$(run_case label-full-auto KEY-1)"
mode="$(get_field "$out" MODE)"
[ "$mode" = "Full Auto" ] && pass "rung 3: AI-Workflow:full-auto -> MODE=Full Auto" \
  || fail "rung 3 (full-auto) — got MODE=$mode"

# --- Rung 3: label precedence — most conservative wins -------------------------------
out="$(run_case label-precedence-multi KEY-1)"
mode="$(get_field "$out" MODE)"
[ "$mode" = "Assisted" ] && pass "rung 3: label precedence — assisted wins over auto" \
  || fail "rung 3 precedence — got MODE=$mode, want Assisted"

# --- Rung 4: neither field nor label set ----------------------------------------------
out="$(run_case none KEY-1)"
mode="$(get_field "$out" MODE)"; src="$(get_field "$out" MODE_SOURCE)"
[ "$mode" = "" ] && [ "$src" = "none" ] \
  && pass "rung 4: neither field nor label set -> MODE=\"\", MODE_SOURCE=none" \
  || fail "rung 4 — got MODE=$mode MODE_SOURCE=$src"

# --- Rung 5: acli errors on every probe -> MODE=""/MODE_SOURCE=none/exit 0 -----------
rc=0
out="$(run_case all-error KEY-1)" || rc=$?
mode="$(get_field "$out" MODE)"; src="$(get_field "$out" MODE_SOURCE)"
if [ "$rc" -eq 0 ] && [ "$mode" = "" ] && [ "$src" = "none" ]; then
  pass "rung 5: acli error on every probe -> MODE=\"\", MODE_SOURCE=none, exit 0"
else
  fail "rung 5 — got rc=$rc MODE=$mode MODE_SOURCE=$src"
fi

# --- Rung 2 retry loop: transient acli error on attempts 1-2, success on attempt 3 -----
counter="$mockdir/counter-transient"
out="$(run_case_counted rung2-transient-then-success KEY-1 "$counter")"
mode="$(get_field "$out" MODE)"; src="$(get_field "$out" MODE_SOURCE)"
attempts="$(cat "$counter" 2>/dev/null || echo 0)"
[ "$mode" = "Assisted" ] && [ "$src" = "field" ] && [ "$attempts" -eq 3 ] \
  && pass "rung 2 retry: transient error x2 then success on attempt 3 -> resolves real mode (MODE=Assisted), exit 0" \
  || fail "rung 2 retry (transient-then-success) — got MODE=$mode MODE_SOURCE=$src attempts=$attempts"

# --- Rung 2 retry loop: persistent acli error on all 3 attempts -----------------------
counter="$mockdir/counter-persistent"
rc=0
out="$(run_case_counted rung2-persistent-error KEY-1 "$counter")" || rc=$?
mode="$(get_field "$out" MODE)"; src="$(get_field "$out" MODE_SOURCE)"
attempts="$(cat "$counter" 2>/dev/null || echo 0)"
if [ "$rc" -eq 0 ] && [ "$mode" = "" ] && [ "$src" = "none" ] && [ "$attempts" -eq 3 ]; then
  pass "rung 2 retry: persistent acli error on all 3 attempts -> MODE=\"\", MODE_SOURCE=none, exit 0"
else
  fail "rung 2 retry (persistent-error) — got rc=$rc MODE=$mode MODE_SOURCE=$src attempts=$attempts"
fi

# --- Rung 2 retry loop: a clean empty result must NOT trigger a retry -----------------
counter="$mockdir/counter-clean-empty"
out="$(run_case_counted rung2-clean-empty-no-retry KEY-1 "$counter")"
mode="$(get_field "$out" MODE)"; src="$(get_field "$out" MODE_SOURCE)"
attempts="$(cat "$counter" 2>/dev/null || echo 0)"
[ "$mode" = "" ] && [ "$src" = "none" ] && [ "$attempts" -eq 1 ] \
  && pass "rung 2 retry: clean empty result on first attempt -> no retry (probe invoked exactly once), falls through to labels" \
  || fail "rung 2 retry (clean-empty-no-retry) — got MODE=$mode MODE_SOURCE=$src attempts=$attempts (want attempts=1)"

echo
if [ "$failures" -ne 0 ]; then
  echo "resolve-ai-workflow-mode.test.sh: FAILED ($failures assertion(s) failed)"
  exit 1
fi
echo "resolve-ai-workflow-mode.test.sh: PASS — all assertions passed"
exit 0
