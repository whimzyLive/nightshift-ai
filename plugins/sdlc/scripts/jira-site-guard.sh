#!/usr/bin/env bash
set -uo pipefail
# jira-site-guard.sh [context-file]
#
# acli holds a single global active Jira site shared across every authenticated account (NA-77):
# a stale/reverted active site makes a Jira call fail with a permission-shaped acli error instead
# of a site-mismatch one. Run this before any acli Jira call so the mismatch fails loud instead.
# Contract pinned by plugins/sdlc/scripts/__tests__/jira-site-guard.test.sh:
#
#   Exit 0  — active site already matched the expected one, or matched after an in-place switch.
#             Silent (no measurable per-call context cost) — this runs ahead of every Jira call.
#   Exit 1  — no acli account stored for the expected site (names the site + the login remedy),
#             the context file/row is missing or unreadable, or a switch reported success but a
#             re-verify still shows the wrong site active. Never assumes or defaults a site.
#
# [context-file] defaults to .claude/project/project-context.md; callers/tests may override it.

ctx="${1:-.claude/project/project-context.md}"

if [ ! -r "$ctx" ]; then
  echo "ERROR: jira-site-guard: cannot read project-context file: $ctx" >&2
  exit 1
fi

expected="$(awk -F'|' '
  tolower($2) ~ /^[ \t]*jira site[ \t]*$/ { val=$3; gsub(/^[ \t]+|[ \t]+$/, "", val); print val; exit }
' "$ctx")"

if [ -z "$expected" ]; then
  echo "ERROR: jira-site-guard: no 'Jira site' row found in $ctx" >&2
  exit 1
fi

active_site() {
  acli jira auth status 2>/dev/null | awk '/^[[:space:]]*Site:/ { print $2; exit }'
}

active="$(active_site)"
if [ "$active" = "$expected" ]; then
  exit 0
fi

if ! acli jira auth switch --site "$expected" >/dev/null 2>&1; then
  echo "ERROR: jira-site-guard: no acli account stored for $expected — run: acli jira auth login --site $expected" >&2
  exit 1
fi

active="$(active_site)"
if [ "$active" != "$expected" ]; then
  echo "ERROR: jira-site-guard: switched to $expected but acli still reports '$active' active — run: acli jira auth login --site $expected" >&2
  exit 1
fi

exit 0
