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
esac
exit 0
MOCK_ACLI
chmod +x "$mockdir/acli"

run_case() { # $1=scenario $2=issue-key
  MOCK_SCENARIO="$1" PATH="$mockdir:$PATH" bash "$script" "$2"
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

echo
if [ "$failures" -ne 0 ]; then
  echo "resolve-ai-workflow-mode.test.sh: FAILED ($failures assertion(s) failed)"
  exit 1
fi
echo "resolve-ai-workflow-mode.test.sh: PASS — all assertions passed"
exit 0
