#!/usr/bin/env bash
set -euo pipefail
# read-review-config.sh [--phase <p>] [context-file]
#
# Single source of truth for the per-repo review configuration. Reads the review
# tokens from `.claude/project/project-context.md` and echoes them as
# shell-assignable lines so callers can `eval` the output:
#
#   eval "$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/read-review-config.sh --phase impl)"
#   # -> sets REVIEW_AGENT, REVIEW_MODE and REVIEW_GATE in the caller's shell
#
# Tokens (looked up in any "## ... Review" section — section name is not matched,
# only the token row, so both "## Copilot Review" and "## Code Review" work):
#
#   Review agent : github-copilot | claude-inline | claude-superpowers   (default: github-copilot)
#   Review mode  : none | on-create | on-update      (default: on-update)
#   Review gate  : comma-separated subset of {spec,plan,impl}  (default: empty = all phases)
#
# - Review agent selects WHO reviews: the GitHub Copilot bot (assigned as a PR
#   reviewer, async), Claude inline (the loop runs /code-review in-session), or
#   claude-superpowers (the loop runs the superpowers requesting-code-review skill
#   in-session — a focused reviewer subagent — instead of native /code-review).
# - Review mode selects the cadence (request once / per-update / not at all) and
#   is orthogonal to the agent.
# - Review gate selects WHICH phases trigger the configured review. It is a
#   comma-separated list of phase names drawn from {spec,plan,impl}. The current
#   phase is supplied by the caller via the OPTIONAL `--phase <p>` flag.
#
# --phase semantics (effective REVIEW_MODE):
#   The flag must be passed literally on the command line (NOT via an env var) so
#   it survives subagent dispatch and /loop re-invocation. When `--phase <p>` is
#   given AND the gate set is non-empty AND <p> is NOT in the gate set, the review
#   for THIS phase is skipped: REVIEW_MODE is downgraded to `none` (the proven
#   no-review path that raise-pr.sh / loop.md already honour). When the gate is
#   empty/absent, NO downgrade happens — every phase reviews (back-compatible
#   default; no regression). Unknown phase tokens in the gate are ignored with a
#   WARNING on stderr; they never fail the read.
#
# Defaulting (AC-5): when "Review agent" is absent OR holds an unrecognised
# value, fall back to github-copilot AND emit a WARNING on stderr. The echoed
# assignment lines (REVIEW_AGENT, REVIEW_MODE, REVIEW_GATE) are the ONLY thing
# printed to stdout, so eval is safe; all diagnostics go to stderr.
#
# Why a script: keeps the grep/sed token-read and the default-and-warn logic in
# ONE place shared by raise-pr.sh and commands/loop.md, instead of duplicating a
# fiddly regex (and the AC-5 warning) across both. Matches the auto-mode
# allowlist `Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/*)` as a single invocation.

# Parse the optional `--phase <p>` flag out FIRST, then treat the first remaining
# positional (if any) as the context file. Do NOT use `${1:-default}` for the
# context file: that falls back on an UNSET arg but NOT on an empty-string arg —
# only default when the positional is genuinely absent.
PHASE=""
POSITIONAL=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --phase)
      PHASE="${2:-}"; shift 2 ;;
    *)
      POSITIONAL+=("$1"); shift ;;
  esac
done
if [ "${#POSITIONAL[@]}" -gt 0 ]; then
  CTX="${POSITIONAL[0]}"
else
  CTX=".claude/project/project-context.md"
fi
PHASE="$(printf '%s' "$PHASE" | tr '[:upper:]' '[:lower:]')"

# Read a single-value token row from a markdown table: `| <Token> | <value> |`.
# Case-insensitive on the token name; strips optional surrounding backticks and
# lower-cases the value. Empty when the row is absent or the file is unreadable.
# The value charset `[A-Za-z-]+` is deliberately the enum alphabet of both tokens
# (github-copilot|claude-inline|claude-superpowers, none|on-create|on-update). If a value contains any
# OTHER char (an underscore typo `github_copilot`, or a trailing phrase like
# `claude-inline (when Copilot is down)`), the whole `s///` fails to match, so sed
# emits the row VERBATIM — read_token then returns the entire (lower-cased) row,
# which fails the `case` match below and trips the AC-5 default+warning. That is the
# intended SAFE outcome (default + warn), but note it means such a value is rejected,
# NOT parsed: a future enum value containing a digit/other char must widen this class
# here, or it too would be silently rejected rather than honoured.
read_token() {
  # `|| true` is load-bearing: under `set -e`/`pipefail`, grep exiting 1 on a no-match
  # (token row absent, or file unreadable) would abort the script mid-command-substitution
  # and print nothing — leaving the caller's REVIEW_AGENT/REVIEW_MODE unset (set -u crash).
  # Swallowing the no-match lets the defaulting below run and the two lines always print.
  grep -iE "^\|[[:space:]]*$1[[:space:]]*\|" "$CTX" 2>/dev/null \
    | sed -E 's/.*\|[^|]*\|[[:space:]]*`?([A-Za-z-]+)`?[[:space:]]*\|.*/\1/' \
    | head -1 | tr '[:upper:]' '[:lower:]' || true
}

# Read a wider-charset token row (letters, commas, spaces, backticks) for the
# comma-separated `Review gate` value. The narrow `[A-Za-z-]+` reader above cannot
# carry commas/spaces, so the gate needs its own class. The value is normalised by
# the caller (lower-cased here, backticks/spaces stripped, split on commas).
read_token_csv() {
  grep -iE "^\|[[:space:]]*$1[[:space:]]*\|" "$CTX" 2>/dev/null \
    | sed -E 's/.*\|[^|]*\|[[:space:]]*([A-Za-z, `]*)[[:space:]]*\|.*/\1/' \
    | head -1 | tr '[:upper:]' '[:lower:]' || true
}

REVIEW_AGENT="$(read_token 'Review agent')"
REVIEW_MODE="$(read_token 'Review mode')"
REVIEW_GATE_RAW="$(read_token_csv 'Review gate')"

# Review agent — github-copilot is the only non-Copilot... i.e. the safe default.
# Absent OR unrecognised both default to github-copilot WITH a warning (AC-5).
case "$REVIEW_AGENT" in
  github-copilot|claude-inline|claude-superpowers) ;;
  '')
    echo "WARNING: review-agent not set in $CTX — defaulting to github-copilot" >&2
    REVIEW_AGENT=github-copilot ;;
  *)
    echo "WARNING: unrecognised review-agent '$REVIEW_AGENT' in $CTX — defaulting to github-copilot" >&2
    REVIEW_AGENT=github-copilot ;;
esac

# Review mode — back-compatible default on-update; no warning (historical behaviour).
case "$REVIEW_MODE" in none|on-create|on-update) ;; *) REVIEW_MODE=on-update ;; esac

# Review gate — normalise the raw CSV into a clean, comma-separated set drawn from
# {spec,plan,impl}. Strip backticks/spaces, split on commas, keep only known phase
# tokens (warn-and-ignore the rest). An empty/absent gate means "all phases review"
# (the default) and must NOT downgrade any phase.
REVIEW_GATE=""
if [ -n "$REVIEW_GATE_RAW" ]; then
  cleaned="$(printf '%s' "$REVIEW_GATE_RAW" | tr -d '` ' )"
  IFS=','; for tok in $cleaned; do
    [ -n "$tok" ] || continue
    case "$tok" in
      spec|plan|impl)
        case ",$REVIEW_GATE," in *",$tok,"*) ;; *) REVIEW_GATE="${REVIEW_GATE:+$REVIEW_GATE,}$tok" ;; esac ;;
      *)
        echo "WARNING: unknown phase '$tok' in Review gate (expected spec|plan|impl) — ignored" >&2 ;;
    esac
  done
  unset IFS
fi

# Effective REVIEW_MODE for THIS phase: if a phase was supplied AND the gate is
# non-empty AND the phase is NOT in the gate set, downgrade to `none` (skip the
# review for this phase). An empty gate never downgrades (all phases review).
if [ -n "$PHASE" ] && [ -n "$REVIEW_GATE" ]; then
  case ",$REVIEW_GATE," in
    *",$PHASE,"*) ;;  # phase is gated — review runs as configured
    *)
      echo "review-gate: phase '$PHASE' not in gate '$REVIEW_GATE' — review skipped for this phase" >&2
      REVIEW_MODE=none ;;
  esac
fi

printf 'REVIEW_AGENT=%s\n' "$REVIEW_AGENT"
printf 'REVIEW_MODE=%s\n' "$REVIEW_MODE"
printf 'REVIEW_GATE=%s\n' "$REVIEW_GATE"
