#!/usr/bin/env bash
set -euo pipefail
# read-review-config.sh [context-file]
#
# Single source of truth for the per-repo review configuration. Reads the two
# review tokens from `.claude/project/project-context.md` and echoes them as two
# shell-assignable lines so callers can `eval` the output:
#
#   eval "$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/read-review-config.sh)"
#   # -> sets REVIEW_AGENT and REVIEW_MODE in the caller's shell
#
# Tokens (looked up in any "## ... Review" section — section name is not matched,
# only the token row, so both "## Copilot Review" and "## Code Review" work):
#
#   Review agent : github-copilot | claude-inline   (default: github-copilot)
#   Review mode  : none | on-create | on-update      (default: on-update)
#
# - Review agent selects WHO reviews: the GitHub Copilot bot (assigned as a PR
#   reviewer, async) or Claude inline (the loop runs /code-review in-session).
# - Review mode selects the cadence (request once / per-update / not at all) and
#   is orthogonal to the agent.
#
# Defaulting (AC-5): when "Review agent" is absent OR holds an unrecognised
# value, fall back to github-copilot AND emit a WARNING on stderr. The two
# echoed assignment lines are the ONLY thing printed to stdout, so eval is safe;
# all diagnostics go to stderr.
#
# Why a script: keeps the grep/sed token-read and the default-and-warn logic in
# ONE place shared by raise-pr.sh and commands/loop.md, instead of duplicating a
# fiddly regex (and the AC-5 warning) across both. Matches the auto-mode
# allowlist `Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/*)` as a single invocation.

CTX="${1:-.claude/project/project-context.md}"

# Read a single-value token row from a markdown table: `| <Token> | <value> |`.
# Case-insensitive on the token name; strips optional surrounding backticks and
# lower-cases the value. Empty when the row is absent or the file is unreadable.
# The value charset `[A-Za-z-]+` is deliberately the enum alphabet of both tokens
# (github-copilot|claude-inline, none|on-create|on-update). A value with any other
# char (e.g. an underscore typo `github_copilot`) captures only the leading run,
# which then fails the `case` match below and trips the AC-5 default+warning — the
# intended outcome. If a future enum value contains a digit/other char, widen this
# class too, or it would be silently clipped.
read_token() {
  # `|| true` is load-bearing: under `set -e`/`pipefail`, grep exiting 1 on a no-match
  # (token row absent, or file unreadable) would abort the script mid-command-substitution
  # and print nothing — leaving the caller's REVIEW_AGENT/REVIEW_MODE unset (set -u crash).
  # Swallowing the no-match lets the defaulting below run and the two lines always print.
  grep -iE "^\|[[:space:]]*$1[[:space:]]*\|" "$CTX" 2>/dev/null \
    | sed -E 's/.*\|[^|]*\|[[:space:]]*`?([A-Za-z-]+)`?[[:space:]]*\|.*/\1/' \
    | head -1 | tr '[:upper:]' '[:lower:]' || true
}

REVIEW_AGENT="$(read_token 'Review agent')"
REVIEW_MODE="$(read_token 'Review mode')"

# Review agent — github-copilot is the only non-Copilot... i.e. the safe default.
# Absent OR unrecognised both default to github-copilot WITH a warning (AC-5).
case "$REVIEW_AGENT" in
  github-copilot|claude-inline) ;;
  '')
    echo "WARNING: review-agent not set in $CTX — defaulting to github-copilot" >&2
    REVIEW_AGENT=github-copilot ;;
  *)
    echo "WARNING: unrecognised review-agent '$REVIEW_AGENT' in $CTX — defaulting to github-copilot" >&2
    REVIEW_AGENT=github-copilot ;;
esac

# Review mode — back-compatible default on-update; no warning (historical behaviour).
case "$REVIEW_MODE" in none|on-create|on-update) ;; *) REVIEW_MODE=on-update ;; esac

printf 'REVIEW_AGENT=%s\n' "$REVIEW_AGENT"
printf 'REVIEW_MODE=%s\n' "$REVIEW_MODE"
