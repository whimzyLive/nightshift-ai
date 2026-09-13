#!/usr/bin/env bash
# pr-number-lib.sh — sourced by pr-unresolved-comments.sh and pr-loop-status.sh.
# Sourced, never executed: no `set -e`, no top-level side effects.

normalize_pr_number() {
  local raw="${1:-}" expected_slug="${2:-}" body after lead trail rest owner repo path url_slug=''
  lead="${raw%%[![:space:]]*}"; raw="${raw#"$lead"}"
  trail="${raw##*[![:space:]]}"; raw="${raw%"$trail"}"
  body="${raw%%[#?]*}"
  case "$body" in
    https://github.com/*|http://github.com/*)
      rest="${body#https://github.com/}"
      [ "$rest" = "$body" ] && rest="${body#http://github.com/}"
      owner="${rest%%/*}"; rest="${rest#*/}"
      repo="${rest%%/*}"; path="${rest#*/}"
      [ -n "$owner" ] && [ -n "$repo" ] && [ "$path" != "$rest" ] || return 1
      url_slug="$owner/$repo"
      body="$path"
      ;;
  esac
  case "$body" in
    pull/*|*/pull/*)
      after="${body#*/pull/}"
      [ "$after" = "$body" ] && after="${body#pull/}"
      body="${after%%/*}"
      ;;
    *) body="${body%/}"; body="${body##*/}" ;;
  esac
  case "$body" in
    ''|*[!0-9]*) return 1 ;;
  esac
  if [ -n "$url_slug" ]; then
    if [ -z "$expected_slug" ]; then
      expected_slug="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
    fi
    [ -n "$expected_slug" ] && [ "$url_slug" = "$expected_slug" ] || return 1
  fi
  printf '%s' "$body"
}
