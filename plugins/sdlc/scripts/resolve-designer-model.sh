#!/usr/bin/env bash
set -euo pipefail
# resolve-designer-model.sh --mode <draft|plan|final> [--context <project-context.md>]
#
# Picks the model for a designer agent dispatch and prints to stdout:
#
#   DESIGNER_MODEL=<model>
#   DESIGNER_MODEL_REASON=default|token
#
# Reads the project-context row `Designer model <mode>` (a model alias or id in the Value column).
# Absent -> the default below. A malformed value warns on stderr and falls back to the default.
# Defaults: draft = opus, plan = sonnet, final = sonnet.

MODE=""; CTX=".claude/project/project-context.md"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --mode)    MODE="${2:-}"; shift 2 ;;
    --context) CTX="${2:-}"; shift 2 ;;
    *) echo "resolve-designer-model.sh: unknown argument '$1'" >&2; exit 2 ;;
  esac
done

case "$MODE" in
  draft) default=opus ;;
  plan|final) default=sonnet ;;
  *) echo "resolve-designer-model.sh: --mode must be draft, plan or final" >&2; exit 2 ;;
esac

value=""
if [ -f "$CTX" ]; then
  value="$(grep -i -m1 -E "^\|[[:space:]]*Designer model $MODE[[:space:]]*\|" "$CTX" \
    | sed -E 's/^\|[^|]*\|[[:space:]]*([^|]*[^|[:space:]])?[[:space:]]*\|.*/\1/' \
    | tr -d '`' || true)"
fi

if [ -z "$value" ]; then
  printf 'DESIGNER_MODEL=%s\nDESIGNER_MODEL_REASON=default\n' "$default"
  exit 0
fi
case "$value" in
  *[!A-Za-z0-9._:-]*)
    echo "WARNING: malformed Designer model $MODE '$value' in $CTX — using $default" >&2
    printf 'DESIGNER_MODEL=%s\nDESIGNER_MODEL_REASON=default\n' "$default" ;;
  *) printf 'DESIGNER_MODEL=%s\nDESIGNER_MODEL_REASON=token\n' "$value" ;;
esac
