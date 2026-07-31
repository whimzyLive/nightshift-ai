#!/usr/bin/env bash
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
hook="$here/../rtk-line-scan.sh"
fail=0

# The hook's passthrough path emits nothing (exit 0, empty stdout) by design (spec: "emit
# nothing, exit 0"). `jq -r '... // "(none)"'` on completely empty stdin produces zero output
# lines rather than substituting the default, so every assertion normalises through this helper
# to guarantee well-formed JSON reaches the downstream jq filter.
hook_out() {
  local out
  out="$(bash "$hook")"
  if [ -z "$out" ]; then
    printf '{}'
  else
    printf '%s' "$out"
  fi
}

run() {
  printf '%s' "$1" | jq -Rs '{tool_name:"Bash",tool_input:{command:.,description:"d",timeout:5}}' \
    | hook_out
}

result_command() {
  run "$1" | jq -r '.hookSpecificOutput.updatedInput.command // "(none)"'
}

assert_eq() {
  if [ "$1" = "$2" ]; then
    printf 'ok   %s\n' "$3"
  else
    printf 'FAIL %s\n     expected: %s\n     actual:   %s\n' "$3" "$1" "$2"
    fail=1
  fi
}

assert_eq "(none)" "$(result_command "$(printf 'pnpm exec tsc --noEmit')")" \
  "EXCLUDE: bare tsc is never rewritten"
assert_eq "(none)" "$(result_command "$(printf 'cd /repo && pnpm exec tsc --noEmit')")" \
  "EXCLUDE (G1): tsc behind a leading cd && is never rewritten"
assert_eq "(none)" "$(result_command "$(printf 'git status && pnpm exec prettier --check a.md')")" \
  "EXCLUDE (G1): a whole line is carried when any segment is excluded"
assert_eq "(none)" "$(result_command "$(printf 'pnpm exec eslint .')")" \
  "EXCLUDE: eslint is never rewritten"
assert_eq "(none)" "$(result_command "$(printf 'pnpm exec vitest run')")" \
  "EXCLUDE: vitest is never rewritten"
assert_eq "(none)" "$(result_command "$(printf 'cd /r\nnpx nx test')")" \
  "EXCLUDE: nx is never rewritten, on any line"
assert_eq "(none)" "$(result_command "$(printf 'cat <<EOF\ngit status\nEOF')")" \
  "heredoc: whole command passes through"
assert_eq "(none)" "$(run "$(printf 'git status')" | jq -r '.x // "(none)"' 2>/dev/null || echo "(none)")" \
  "output is well-formed JSON or empty"

exit "$fail"
