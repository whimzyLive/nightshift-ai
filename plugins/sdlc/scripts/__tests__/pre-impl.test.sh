#!/usr/bin/env bash
# pre-impl.test.sh — pre-impl.sh against a real temp git origin, with gh/acli mocked and the
# dep-gate / worktree-setup / site-guard siblings stubbed.
#   bash plugins/sdlc/scripts/__tests__/pre-impl.test.sh
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
src="$here/../pre-impl.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/scripts" "$work/bin"
cp "$src" "$work/scripts/pre-impl.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$work/scripts/jira-site-guard.sh"

cat > "$work/scripts/dep-gate.sh" <<'EOF'
#!/usr/bin/env bash
case "${MOCK_GATE:-pass}" in
  pass) echo "BLOCKERS="; echo "UI_BLOCKERS="; echo "GATE=PASS" ;;
  ui) echo "BLOCKERS=S-0"; echo "S-0 PR: yes"; echo "UI_BLOCKERS=S-0"; echo "GATE=PASS" ;;
  stop) echo "BLOCKERS=S-0"; echo "S-0 PR: NO"; echo "UI_BLOCKERS="; echo "REASON=blocker S-0 has no PR"; echo "GATE=STOP"; exit 1 ;;
esac
EOF

# A real worktree, created the way worktree-setup.sh does: the branch lives only in it.
cat > "$work/scripts/worktree-setup.sh" <<'EOF'
#!/usr/bin/env bash
set -e
key="$1" branch="$2" base="$3" wt="$PWD/.wt/$key"
if git ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
  git fetch -q origin "$branch"
  git worktree add -q -B "$branch" "$wt" "origin/$branch" >/dev/null 2>&1
else
  git worktree add -q -b "$branch" "$wt" "origin/$base" >/dev/null 2>&1
fi
echo "WORKTREE=$wt"
echo "NX_CACHE_DIRECTORY=$PWD/.nx/cache"
EOF

cat > "$work/bin/gh" <<'EOF'
#!/usr/bin/env bash
case "${MOCK_PR:-none}" in
  none) echo '[]' ;;
  open) echo '[{"state":"OPEN"}]' ;;
  merged) echo '[{"state":"CLOSED"},{"state":"MERGED"}]' ;;
esac
EOF

cat > "$work/bin/acli" <<'EOF'
#!/usr/bin/env bash
case "${MOCK_SUBS:-none}" in
  none) echo '[]' ;;
  two) echo '[{"key":"S-1a","fields":{"summary":"first"}},{"key":"S-1b","fields":{"summary":"second"}}]' ;;
  error) exit 1 ;;
esac
EOF
chmod +x "$work/bin/"* "$work/scripts/"*.sh

# fresh_repo -> a bare origin with develop, and a primary clone; echoes the primary path.
fresh_repo() {
  local d; d="$(mktemp -d "$work/repo.XXXX")"
  git init -q --bare "$d/origin.git"
  git clone -q "$d/origin.git" "$d/primary" 2>/dev/null
  (
    cd "$d/primary" || exit 1
    git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
    git branch -q -M develop
    git push -q origin develop
  )
  echo "$d/primary"
}

# add_remote_branch <primary> <branch> <file> — push a branch carrying <file> to origin.
add_remote_branch() {
  (
    cd "$1" || exit 1
    git checkout -q -b "$2" origin/develop
    mkdir -p "$(dirname "$3")"; echo spec > "$3"; git add "$3"
    git -c user.email=t@t -c user.name=t commit -q -m "add $3"
    git push -q origin "$2"
    git checkout -q develop
    git branch -q -D "$2"
  )
}

pass=0 fail=0
OUT="" RC=0
run() {
  local repo="$1" light="$2"; shift 2
  OUT="$(cd "$repo" && env PATH="$work/bin:$PATH" "$@" bash "$work/scripts/pre-impl.sh" S-1 feat develop "$light" 2>/dev/null)"; RC=$?
}
expect() {
  local name="$1" ok="$2"
  if [ "$ok" = 0 ]; then pass=$((pass + 1)); echo "ok   $name"; else fail=$((fail + 1)); echo "FAIL $name"; printf '%s\n' "$OUT" | sed 's/^/     /'; fi
}
has() { printf '%s\n' "$OUT" | grep -qxF -- "$1"; }

r="$(fresh_repo)"; run "$r" true
base="$(git -C "$r" rev-parse origin/develop)"
has "RESULT=ok" && has "BASE_SHA=$base" && has "PR_STATE=none" && has "SUBTASK_COUNT=0" \
  && git -C "$r" ls-remote --exit-code --heads origin feat/S-1 >/dev/null
expect "lightweight: ok, BASE_SHA, branch pushed" $?

r="$(fresh_repo)"; run "$r" false
[ "$RC" -eq 1 ] && has "RESULT=stop" && printf '%s\n' "$OUT" | grep -q '^REASON=no approved spec' \
  && ! git -C "$r" ls-remote --exit-code --heads origin feat/S-1 >/dev/null
expect "full path without a spec stops before branching" $?

r="$(fresh_repo)"; add_remote_branch "$r" feat/S-1 docs/superpowers/specs/S-1.md; run "$r" false
[ "$RC" -eq 0 ] && has "RESULT=ok" && [ -f "$r/.wt/S-1/docs/superpowers/specs/S-1.md" ]
expect "full path with the approved spec on the branch reuses it" $?

r="$(fresh_repo)"; run "$r" true MOCK_PR=merged
[ "$RC" -eq 1 ] && printf '%s\n' "$OUT" | grep -q '^REASON=feat/S-1 already has a merged PR'
expect "merged PR stops" $?

r="$(fresh_repo)"; run "$r" true MOCK_GATE=stop
[ "$RC" -eq 1 ] && printf '%s\n' "$OUT" | grep -q '^REASON=dependency gate: blocker S-0 has no PR' \
  && has "S-0 PR: NO" && [ ! -d "$r/.wt/S-1" ]
expect "dependency gate stop: no worktree, blocker lines surfaced" $?

r="$(fresh_repo)"; run "$r" true MOCK_SUBS=two
has "SUBTASK_COUNT=2" && [ "$(printf '%s\n' "$OUT" | grep '^SUBTASK=' | cut -f1 | tr '\n' ' ')" = "SUBTASK=S-1a SUBTASK=S-1b " ] \
  && has "$(printf 'SUBTASK=S-1a\tfirst')"
expect "sub-tasks listed in Jira order" $?

r="$(fresh_repo)"; run "$r" true MOCK_SUBS=error
[ "$RC" -eq 1 ] && printf '%s\n' "$OUT" | grep -q '^REASON=sub-task probe failed' && [ ! -d "$r/.wt/S-1" ]
expect "sub-task probe error stops before branching" $?

r="$(fresh_repo)"; add_remote_branch "$r" feat/S-1 src/a.txt
( cd "$r" && echo b > b.txt && git add b.txt && git -c user.email=t@t -c user.name=t commit -q -m "base moves" && git push -q origin develop )
run "$r" true MOCK_PR=open MOCK_GATE=ui
[ "$RC" -eq 0 ] && has "UI_BLOCKERS=S-0" && has "PR_STATE=open" && [ -f "$r/.wt/S-1/b.txt" ]
expect "reused branch with a UI-Components blocker merges the base in" $?

# The spec-first case: /spec pushed the branch earlier, no PR yet, and the base moved since.
r="$(fresh_repo)"; add_remote_branch "$r" feat/S-1 docs/superpowers/specs/S-1.md
( cd "$r" && echo c > c.txt && git add c.txt && git -c user.email=t@t -c user.name=t commit -q -m "base moves" && git push -q origin develop )
run "$r" false
wt="$r/.wt/S-1"
[ "$RC" -eq 0 ] && has "PR_STATE=none" && [ -f "$wt/c.txt" ] \
  && [ -z "$(git -C "$wt" diff --name-only "$(printf '%s\n' "$OUT" | sed -n 's/^BASE_SHA=//p')" HEAD -- c.txt)" ]
expect "spec-first branch with no PR: base merged in, BASE_SHA..HEAD excludes base commits" $?

r="$(fresh_repo)"
( cd "$r" && mkdir -p docs/superpowers/specs && echo s > docs/superpowers/specs/S-1.md && git add . \
  && git -c user.email=t@t -c user.name=t commit -q -m "legacy spec" && git push -q origin develop )
run "$r" false
[ "$RC" -eq 0 ] && has "RESULT=ok"
expect "legacy spec merged to the base branch satisfies the full path" $?

echo "pre-impl: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
