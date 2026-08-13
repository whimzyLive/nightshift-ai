#!/usr/bin/env bash
# pr-number-lib.sh — sourced by pr-unresolved-comments.sh and pr-loop-status.sh.
# Sourced, never executed: no `set -e`, no top-level side effects.

normalize_pr_number() {
  local raw="${1:-}" body after lead trail
  lead="${raw%%[![:space:]]*}"; raw="${raw#"$lead"}"
  trail="${raw##*[![:space:]]}"; raw="${raw%"$trail"}"
  body="${raw%%[#?]*}"
  case "$body" in
    */pull/*) after="${body#*/pull/}"; body="${after%%/*}" ;;
    *) body="${body%/}"; body="${body##*/}" ;;
  esac
  case "$body" in
    ''|*[!0-9]*) return 1 ;;
  esac
  printf '%s' "$body"
}
