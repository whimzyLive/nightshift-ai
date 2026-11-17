#!/usr/bin/env bash
# repo-behind.test.sh — CI guard for the SessionStart hook's "REPO BEHIND" warning. Uses a local
# bare repo as origin; no network.
#   bash plugins/sdlc/scripts/__tests__/repo-behind.test.sh
set -uo pipefail

here="${BASH_SOURCE[0]%/*}"; [ "$here" = "${BASH_SOURCE[0]}" ] && here="."
hook="$(cd "$here/../../hooks" && pwd)/load-project-context.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

pass=0; fail=0
check() { # name cmd...
  local name="$1"; shift
  if "$@"; then pass=$((pass + 1)); echo "ok   $name"; else fail=$((fail + 1)); echo "FAIL $name"; fi
}
run_hook() { # dir -> stdout of hook, exit status preserved in $hook_rc
  out="$(CLAUDE_PROJECT_DIR="$1" CLAUDE_PLUGIN_ROOT="" bash "$hook" 2>/dev/null)"; hook_rc=$?
}
has() { case "$out" in *"$1"*) return 0 ;; *) return 1 ;; esac; }
hasnt() { ! has "$1"; }

git init -q --bare -b main "$work/origin.git"
git clone -q "$work/origin.git" "$work/seed" 2>/dev/null
( cd "$work/seed" && git checkout -q -b main 2>/dev/null; echo a > f; git add f; git commit -qm one; git push -q origin main
  git checkout -q -b epic/x; git push -q origin epic/x ) >/dev/null 2>&1
git clone -q "$work/origin.git" "$work/primary" 2>/dev/null
git -C "$work/primary" checkout -q main
git -C "$work/primary" checkout -q -b epic/x origin/epic/x 2>/dev/null
git -C "$work/primary" checkout -q main
mkdir -p "$work/primary/.claude/project"

push_commits() { # branch n
  ( cd "$work/seed" && git checkout -q "$1" && for i in $(seq 1 "$2"); do echo "$i" >> f; git commit -qam "c$i"; done && git push -q origin "$1" ) >/dev/null 2>&1
}

run_hook "$work/primary"
check "up to date: no warning" hasnt "REPO BEHIND"

push_commits main 3
run_hook "$work/primary"
check "behind by 3: warning names count and ref" has "3 commit(s) behind origin/main"
check "behind: hook exits 0" test "$hook_rc" -eq 0
check "behind: output is JSON additionalContext" has '"additionalContext"'

git -C "$work/primary" worktree add -q "$work/wt" -b wt-branch main 2>/dev/null
run_hook "$work/wt"
check "linked worktree: no warning" hasnt "REPO BEHIND"

git -C "$work/primary" checkout -q epic/x
push_commits epic/x 2
run_hook "$work/primary"
check "epic/x compares against origin/epic/x" has "2 commit(s) behind origin/epic/x"

git -C "$work/primary" checkout -q -b feat/story main
run_hook "$work/primary"
check "feature branch compares against base" has "behind origin/main"

git -C "$work/primary" remote set-url origin "$work/missing.git"
t0=$SECONDS
run_hook "$work/primary"
check "unreachable origin: no warning, hook succeeds" hasnt "REPO BEHIND"
check "unreachable origin: exit 0" test "$hook_rc" -eq 0
check "unreachable origin: bounded under 8s" test $((SECONDS - t0)) -lt 8

git -C "$work/primary" remote remove origin
run_hook "$work/primary"
check "no origin: no warning, exit 0" test "$hook_rc" -eq 0 -a -z "$(printf '%s' "$out" | grep 'REPO BEHIND')"

mkdir -p "$work/plain"
run_hook "$work/plain"
check "not a git repo: silent, exit 0" test "$hook_rc" -eq 0 -a -z "$out"

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
