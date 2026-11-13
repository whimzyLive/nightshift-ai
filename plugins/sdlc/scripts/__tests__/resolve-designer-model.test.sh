#!/usr/bin/env bash
# resolve-designer-model.test.sh — pins the per-mode designer model defaults and the project-context
# `Designer model <mode>` override in scripts/resolve-designer-model.sh. Hermetic: temp context files.
#   bash plugins/sdlc/scripts/__tests__/resolve-designer-model.test.sh
set -uo pipefail

here="${BASH_SOURCE[0]%/*}"; [ "$here" = "${BASH_SOURCE[0]}" ] && here="."
resolve="$(cd "$here/.." && pwd)/resolve-designer-model.sh"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
failures=0
check() { if [ "$2" = "$3" ]; then echo "ok   - $1"; else echo "FAIL - $1: expected '$2', got '$3'"; failures=$((failures + 1)); fi; }
model_of() { bash "$resolve" "$@" 2>/dev/null | sed -n 's/^DESIGNER_MODEL=//p'; }
reason_of() { bash "$resolve" "$@" 2>/dev/null | sed -n 's/^DESIGNER_MODEL_REASON=//p'; }
ctx() { printf '## Design\n\n| Token | Value |\n| --- | --- |\n%s\n' "$1" >"$work/ctx.md"; }

check "no context file: draft -> opus"  opus   "$(model_of --mode draft --context "$work/none.md")"
check "no context file: plan -> sonnet" sonnet "$(model_of --mode plan --context "$work/none.md")"
check "no context file: final -> sonnet" sonnet "$(model_of --mode final --context "$work/none.md")"
ctx ''
check "absent row reason"               default "$(reason_of --mode draft --context "$work/ctx.md")"
ctx '| Designer model draft | `sonnet` |
| Designer model plan | `opus` |'
check "draft override"                  sonnet "$(model_of --mode draft --context "$work/ctx.md")"
check "plan override"                   opus   "$(model_of --mode plan --context "$work/ctx.md")"
check "override reason"                 token  "$(reason_of --mode plan --context "$work/ctx.md")"
check "unset mode keeps its default"    sonnet "$(model_of --mode final --context "$work/ctx.md")"
ctx '| Designer model draft | claude opus 4 |'
check "malformed -> default"            opus   "$(model_of --mode draft --context "$work/ctx.md")"
check "malformed warns"                 1      "$(bash "$resolve" --mode draft --context "$work/ctx.md" 2>&1 >/dev/null | grep -c '^WARNING: malformed')"
ctx '| Designer model final | `claude-sonnet-4-6` |'
check "model id accepted"               claude-sonnet-4-6 "$(model_of --mode final --context "$work/ctx.md")"
check "bad mode exits 2"                2      "$(bash "$resolve" --mode nope >/dev/null 2>&1; echo $?)"
check "unknown flag exits 2"            2      "$(bash "$resolve" --bogus >/dev/null 2>&1; echo $?)"

if [ "$failures" -eq 0 ]; then echo "PASS: resolve-designer-model"; exit 0; fi
echo "FAIL: $failures resolve-designer-model case(s) failed"; exit 1
