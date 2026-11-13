#!/usr/bin/env bash
# library-blockers.sh <EPIC> [--context <project-context.md>] [--label <label>]
#
# Lists the Epic's library stories that are not Done. The final design mode runs only when none are
# left: a screen board is mounted from the component library, so the library must have landed first.
# The label is the project-context `Library label` row (default `Library`); --label overrides it.
#
# Output (greppable):
#   BLOCKERS=<space-separated keys, empty when none>
#   exit 0 -> the query ran (BLOCKERS may still list keys; callers branch on it)
#   exit 1 -> REASON=<why>, the query could not be answered (treat as blocked)
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
epic="${1:?usage: library-blockers.sh <EPIC> [--context <file>] [--label <label>]}"; shift
CTX=".claude/project/project-context.md"; LABEL=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --context) CTX="${2:-}"; shift 2 ;;
    --label)   LABEL="${2:-}"; shift 2 ;;
    *) echo "library-blockers.sh: unknown argument '$1'" >&2; exit 2 ;;
  esac
done

fail() { echo "REASON=$1"; exit 1; }

if [ -z "$LABEL" ] && [ -f "$CTX" ]; then
  LABEL="$(grep -i -m1 -E '^\|[[:space:]]*Library label[[:space:]]*\|' "$CTX" \
    | sed -E 's/^\|[^|]*\|[[:space:]]*([^|]*[^|[:space:]])?[[:space:]]*\|.*/\1/' | tr -d '`' || true)"
fi
LABEL="${LABEL:-Library}"
case "$LABEL" in *[!A-Za-z0-9_-]*) fail "unusable library label '$LABEL'" ;; esac

guard_err="$(bash "$here/jira-site-guard.sh" 2>&1)" || fail "jira-site-guard: ${guard_err:-unknown failure}"

json="$(acli jira workitem search --jql "parent = $epic AND labels = \"$LABEL\" AND statusCategory != Done" --json 2>/dev/null)" \
  || fail "cannot list library stories of $epic (cannot verify)"
keys="$(printf '%s' "$json" | jq -r '[.[]?.key // empty] | join(" ")' 2>/dev/null)" \
  || fail "unreadable acli output for $epic (cannot verify)"
echo "BLOCKERS=$keys"
