#!/usr/bin/env bash
# run-bg.test.sh — the --model run-bg.sh passes to claude on start and resume, with claude stubbed on PATH.
#   bash plugins/sdlc/scripts/__tests__/run-bg.test.sh
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

repo="$work/repo"
mkdir -p "$repo/scripts" "$repo/.claude/project" "$work/bin"
cp "$here/../run-bg.sh" "$repo/scripts/"
git -C "$repo" init -q
printf '#!/usr/bin/env bash\nfor a in "$@"; do printf "[%%s]" "$a"; done > "$CLAUDE_LOG"\n' > "$work/bin/claude"
chmod +x "$work/bin/claude"

SID=39d88595-1111-2222-3333-444444444444
pass=0 fail=0
run() { rm -f "$work/claude.log"; (cd "$repo" && env PATH="$work/bin:$PATH" CLAUDE_LOG="$work/claude.log" bash scripts/run-bg.sh "$@"); }
expect() { # name want
  if grep -qF -- "$2" "$work/claude.log"; then pass=$((pass + 1)); echo "ok   $1"; else fail=$((fail + 1)); echo "FAIL $1 (want '$2')"; cat "$work/claude.log"; echo; fi
}

run S-1
expect "start: default model is sonnet" "[--model][sonnet]"
run S-1 "go" "$SID"
expect "resume: default model is sonnet" "[--model][sonnet]"

echo 'BG_RUN_MODEL=opus' > "$repo/.claude/project/bg-run.env"
run S-1
expect "start: BG_RUN_MODEL overrides" "[--model][opus]"
run S-1 "go" "$SID"
expect "resume: BG_RUN_MODEL overrides" "[--model][opus]"

echo "$pass passed, $fail failed"
[ "$fail" = 0 ]
