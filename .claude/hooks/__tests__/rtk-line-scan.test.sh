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

assert_eq "$(printf 'rtk git status\nrtk git log --oneline -3')" \
  "$(result_command "$(printf 'git status\ngit log --oneline -3')")" \
  "scans line 2 (the F3 defect)"

assert_eq "$(printf 'cd /repo\nrtk git status\nrtk grep -n a b.md')" \
  "$(result_command "$(printf 'cd /repo\ngit status\ngrep -n a b.md')")" \
  "a leading cd no longer disables the whole call"

assert_eq "$(printf 'export X=1\nrtk git status')" \
  "$(result_command "$(printf 'export X=1\ngit status')")" \
  "a leading export no longer disables the whole call"

assert_eq "$(printf 'if true; then\n    rtk git status\nfi')" \
  "$(result_command "$(printf 'if true; then\n    git status\nfi')")" \
  "leading indentation is preserved"

assert_eq "$(printf 'rtk git commit -m "line one\ngit status\nline three"')" \
  "$(result_command "$(printf 'git commit -m "line one\ngit status\nline three"')")" \
  "lines inside an unterminated quote are carried untouched"

assert_eq "(none)" "$(result_command "$(printf 'rtk git status\nrtk git log --oneline -3')")" \
  "idempotent: an already-rewritten command emits nothing"

assert_eq "(none)" "$(result_command "$(printf 'echo hi\necho there')")" \
  "no eligible line emits nothing"

assert_eq "(none)" "$(jq -n '{tool_name:"Read",tool_input:{file_path:"/x"}}' | hook_out \
  | jq -r '.hookSpecificOutput.updatedInput.command // "(none)"')" \
  "a non-Bash tool call is ignored"

assert_eq "(none)" "$(printf 'not json' | hook_out \
  | jq -r '.hookSpecificOutput.updatedInput.command // "(none)"' 2>/dev/null || echo "(none)")" \
  "malformed stdin passes through"

assert_eq "d" "$(run "$(printf 'git status\ngit log --oneline -3')" \
  | jq -r '.hookSpecificOutput.updatedInput.description')" \
  "sibling tool_input fields are copied verbatim"

assert_eq "allow" "$(run "$(printf 'git status\ngit log --oneline -3')" \
  | jq -r '.hookSpecificOutput.permissionDecision')" \
  "permissionDecision is always emitted on a rewrite"

# $(...) strips trailing newlines, so building this two-line string through a command
# substitution collapses it back to one line and silently stops testing G2 at all. Assign the
# literal continuation directly via ANSI-C quoting instead. Per `rtk hook check -- 'foo \'`
# (no rewrite), line 1 stays untouched; the continuation guard must then also keep line 2's
# `git status` untouched rather than rewriting it into `foo \`'s argument list — so the whole
# command is unchanged and the hook emits nothing.
cont_in=$'foo \\\ngit status'
assert_eq "(none)" "$(result_command "$cont_in")" \
  "G2: a backslash-continuation line is not rewritten into the previous command"

exit "$fail"
