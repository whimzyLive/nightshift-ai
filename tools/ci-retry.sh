#!/usr/bin/env bash
set -uo pipefail
#
# ci-retry.sh <command> [args...]
#
# Runs <command> [args...], retrying on non-zero exit until it succeeds or the
# attempt ceiling is hit. CI observes the FINAL attempt's exit status.
#
# Ceiling source (first match wins):
#   1. CI_MAX_ATTEMPTS env var
#   2. `| Max attempts | <n> |` row under a `## CI` section in
#      .claude/project/project-context.md (backticks stripped)
#   3. default: 5
#
# A missing file/section/token, or a non-positive-integer value, falls back to
# the default with a WARNING on stderr — malformed config never fails CI.
# 1 attempt means no retry. Backoff between attempts is a fixed 2s sleep,
# bounded and simple — this exists for transient network blips, not to wait
# out sustained outages.
#
# Diagnostics (attempt/of/status lines, final-failure banner) go to stderr;
# the wrapped command's own stdout/stderr pass through unbuffered.
#
# Exit code: the wrapped command's exit status from its final attempt.

CTX=".claude/project/project-context.md"
DEFAULT_MAX_ATTEMPTS=5
SLEEP_SECONDS=2

if [ "$#" -lt 1 ]; then
  echo "usage: ci-retry.sh <command> [args...]" >&2
  exit 2
fi

read_max_attempts_from_file() {
  grep -iE '^\|[[:space:]]*Max attempts[[:space:]]*\|' "$CTX" 2>/dev/null \
    | sed -E 's/.*\|[^|]*\|[[:space:]]*`?([0-9]+)`?[[:space:]]*\|.*/\1/' \
    | head -1 || true
}

MAX_ATTEMPTS="${CI_MAX_ATTEMPTS:-}"
if [ -n "$MAX_ATTEMPTS" ]; then
  case "$MAX_ATTEMPTS" in
    ''|*[!0-9]*)
      echo "WARNING: CI_MAX_ATTEMPTS='$MAX_ATTEMPTS' is not a positive integer — defaulting to $DEFAULT_MAX_ATTEMPTS" >&2
      MAX_ATTEMPTS="$DEFAULT_MAX_ATTEMPTS" ;;
    0)
      echo "WARNING: CI_MAX_ATTEMPTS=0 is not a positive integer — defaulting to $DEFAULT_MAX_ATTEMPTS" >&2
      MAX_ATTEMPTS="$DEFAULT_MAX_ATTEMPTS" ;;
  esac
else
  FILE_VALUE="$(read_max_attempts_from_file)"
  case "$FILE_VALUE" in
    ''|*[!0-9]*)
      echo "WARNING: 'Max attempts' not set (or unparseable) in $CTX — defaulting to $DEFAULT_MAX_ATTEMPTS" >&2
      MAX_ATTEMPTS="$DEFAULT_MAX_ATTEMPTS" ;;
    0)
      echo "WARNING: 'Max attempts' is 0 in $CTX — must be a positive integer — defaulting to $DEFAULT_MAX_ATTEMPTS" >&2
      MAX_ATTEMPTS="$DEFAULT_MAX_ATTEMPTS" ;;
    *)
      MAX_ATTEMPTS="$FILE_VALUE" ;;
  esac
fi

attempt=1
while :; do
  "$@"
  status=$?
  if [ "$status" -eq 0 ]; then
    exit 0
  fi
  if [ "$attempt" -ge "$MAX_ATTEMPTS" ]; then
    echo "ci-retry: attempt $attempt/$MAX_ATTEMPTS failed (exit $status) — RETRIES EXHAUSTED, giving up on: $*" >&2
    exit "$status"
  fi
  echo "ci-retry: attempt $attempt/$MAX_ATTEMPTS failed (exit $status) — retrying: $*" >&2
  sleep "$SLEEP_SECONDS"
  attempt=$((attempt + 1))
done
