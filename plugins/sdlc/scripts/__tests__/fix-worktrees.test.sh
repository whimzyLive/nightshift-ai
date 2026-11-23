#!/usr/bin/env bash
# fix-worktrees.test.sh — fix-worktrees.sh against real temp git repos; `cp` is shimmed so the
# copy-on-write clone succeeds or fails the same way on every filesystem. No network.
#   bash plugins/sdlc/scripts/__tests__/fix-worktrees.test.sh
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
src="$here/../fix-worktrees.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/ok" "$work/nocow"
real_cp="$(command -v cp)"

# cow shim: accept the clone flags and do a plain copy
cat > "$work/ok/cp" <<EOF
#!/usr/bin/env bash
args=()
for a in "\$@"; do
  case "\$a" in -c | -cRP | --reflink=always) ;; *) args+=("\$a") ;; esac
done
exec "$real_cp" -RP "\${args[@]}"
EOF
# no-CoW shim: every clone attempt fails, as on ext4
printf '#!/usr/bin/env bash\nexit 1\n' > "$work/nocow/cp"
chmod +x "$work/ok/cp" "$work/nocow/cp"

export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

# fresh_repo -> prints the primary checkout; the story worktree sdlc-S-1 is on feat/S-1 with an
# installed (untracked, ignored) node_modules at the root and in one package.
fresh_repo() {
  local d
  d="$(mktemp -d "$work/r.XXXXXX")"
  (
    cd "$d" || exit 1
    git init -q --bare origin.git
    git clone -q origin.git primary 2>/dev/null
    cd primary || exit 1
    printf 'node_modules/\n.claude/worktrees/\n' > .gitignore
    mkdir -p apps/web apps/api
    printf 'one\ntwo\nthree\n' > shared.txt
    echo w > apps/web/a.txt
    echo a > apps/api/a.txt
    git add -A
    git commit -q -m init
    git branch -q -M main
    git push -q origin main
    git worktree add -q -b feat/S-1 .claude/worktrees/sdlc-S-1 origin/main >/dev/null 2>&1
    mkdir -p .claude/worktrees/sdlc-S-1/node_modules/.bin .claude/worktrees/sdlc-S-1/apps/web/node_modules
    echo lock > .claude/worktrees/sdlc-S-1/node_modules/.sdlc-lock-hash
    echo dep > .claude/worktrees/sdlc-S-1/apps/web/node_modules/dep.txt
  ) || exit 1
  echo "$d/primary"
}

pass=0 fail=0
OUT="" RC=0
run() {
  local repo="$1" shim="$2"
  shift 2
  OUT="$(cd "$repo" && env PATH="$work/$shim:$PATH" bash "$src" "$@" 2>/dev/null)"
  RC=$?
}
expect() {
  if [ "$2" = 0 ]; then pass=$((pass + 1)); echo "ok   $1"; else fail=$((fail + 1)); echo "FAIL $1 (rc=$RC)"; printf '%s\n' "$OUT" | sed 's/^/     /'; fi
}
has() { printf '%s\n' "$OUT" | grep -qxF -- "$1"; }
# commit_in <repo> <tag> <file> <content> — what a fix agent does in its worktree
commit_in() {
  (
    cd "$1/.claude/worktrees/sdlc-S-1-fix-$2" || exit 1
    mkdir -p "$(dirname "$3")"
    printf '%s\n' "$4" > "$3"
    git add -A
    git commit -q -m "fix($2): $3"
  )
}
story_head() { git -C "$1/.claude/worktrees/sdlc-S-1" rev-parse HEAD; }

# --- enabled -----------------------------------------------------------------------------
r="$(fresh_repo)"
run "$r" ok enabled
[ "$RC" -ne 0 ]
expect "enabled: no project-context row means off" $?
mkdir -p "$r/.claude/project"
printf '| SDLC parallel fixes | `disabled` |\n' > "$r/.claude/project/project-context.md"
run "$r" ok enabled
[ "$RC" -ne 0 ]
expect "enabled: disabled means off" $?
printf '| SDLC agent reuse | `enabled` |\n| SDLC parallel fixes | `enabled` |\n' > "$r/.claude/project/project-context.md"
run "$r" ok enabled
[ "$RC" -eq 0 ]
expect "enabled: enabled means on, and the reuse row is not mistaken for it" $?
printf '| SDLC agent reuse | `enabled` |\n' > "$r/.claude/project/project-context.md"
run "$r" ok enabled
[ "$RC" -ne 0 ]
expect "enabled: agent reuse enabled alone does not turn it on" $?

# --- add ---------------------------------------------------------------------------------
r="$(fresh_repo)"
run "$r" ok add S-1 web
fw="$r/.claude/worktrees/sdlc-S-1-fix-web"
[ "$RC" -eq 0 ] && has "WORKTREE=$(cd "$r" && pwd -P)/.claude/worktrees/sdlc-S-1-fix-web"
expect "add: prints the worktree path" $?
has "FIX_BRANCH=sdlc-fix/S-1-web" && has "BASE_SHA=$(story_head "$r")"
expect "add: prints the fix branch and the story HEAD it forked from" $?
[ "$(git -C "$fw" rev-parse --abbrev-ref HEAD)" = "sdlc-fix/S-1-web" ] && [ "$(git -C "$fw" rev-parse HEAD)" = "$(story_head "$r")" ]
expect "add: fix worktree is on its own branch at the story HEAD" $?
[ "$(cat "$fw/node_modules/.sdlc-lock-hash")" = lock ] && [ "$(cat "$fw/apps/web/node_modules/dep.txt")" = dep ]
expect "add: root and package node_modules are cloned, not installed" $?

run "$r" nocow add S-1 api
[ "$RC" -eq 3 ] && [ ! -d "$r/.claude/worktrees/sdlc-S-1-fix-api" ] \
  && ! git -C "$r" show-ref --verify --quiet refs/heads/sdlc-fix/S-1-api
expect "add: no copy-on-write clone -> exit 3, worktree and branch removed again" $?

run "$r" ok add S-9 web
[ "$RC" -eq 1 ]
expect "add: no story worktree -> exit 1" $?
run "$r" ok add S-1 'we b'
[ "$RC" -eq 2 ]
expect "add: unsafe tag -> exit 2" $?

# --- merge: disjoint domains -------------------------------------------------------------
r="$(fresh_repo)"
run "$r" ok add S-1 web
run "$r" ok add S-1 api
commit_in "$r" web apps/web/b.txt web1
commit_in "$r" web apps/web/c.txt web2
commit_in "$r" api apps/api/b.txt api1
run "$r" ok merge S-1 web
[ "$RC" -eq 0 ] && has "RESULT=merged COMMITS=2"
expect "merge: first agent's two commits come back" $?
run "$r" ok merge S-1 api
[ "$RC" -eq 0 ] && has "RESULT=merged COMMITS=1"
expect "merge: second agent applies on top of the first" $?
sw="$r/.claude/worktrees/sdlc-S-1"
[ -f "$sw/apps/web/b.txt" ] && [ -f "$sw/apps/web/c.txt" ] && [ -f "$sw/apps/api/b.txt" ] \
  && [ -z "$(git -C "$sw" status --porcelain)" ] \
  && [ "$(git -C "$sw" log --format=%s -3 | tr '\n' '|')" = "fix(api): apps/api/b.txt|fix(web): apps/web/c.txt|fix(web): apps/web/b.txt|" ]
expect "merge: story branch has all three commits in order, tree clean" $?
run "$r" ok remove S-1
[ ! -d "$r/.claude/worktrees/sdlc-S-1-fix-web" ] && [ ! -d "$r/.claude/worktrees/sdlc-S-1-fix-api" ] \
  && ! git -C "$r" show-ref --verify --quiet refs/heads/sdlc-fix/S-1-web \
  && [ -d "$sw" ] && [ "$RC" -eq 0 ]
expect "remove: no tag drops every fix worktree and branch, never the story worktree" $?
run "$r" ok remove S-1
[ "$RC" -eq 0 ]
expect "remove: repeat is a no-op" $?

# --- merge: conflict falls back, story branch untouched -----------------------------------
r="$(fresh_repo)"
run "$r" ok add S-1 web
run "$r" ok add S-1 api
commit_in "$r" web shared.txt "$(printf 'one\nWEB\nthree')"
commit_in "$r" api apps/api/b.txt api1
commit_in "$r" api shared.txt "$(printf 'one\nAPI\nthree')"
run "$r" ok merge S-1 web
[ "$RC" -eq 0 ]
expect "conflict setup: first agent merges" $?
sw="$r/.claude/worktrees/sdlc-S-1"
before="$(story_head "$r")"
run "$r" ok merge S-1 api
[ "$RC" -eq 5 ] && has "RESULT=conflict"
expect "merge: overlapping edit -> RESULT=conflict, exit 5" $?
[ "$(story_head "$r")" = "$before" ] && [ -z "$(git -C "$sw" status --porcelain)" ] \
  && [ ! -f "$sw/apps/api/b.txt" ] && grep -q WEB "$sw/shared.txt" \
  && [ ! -e "$sw/.git/CHERRY_PICK_HEAD" ] && ! git -C "$sw" rev-parse -q --verify CHERRY_PICK_HEAD >/dev/null
expect "merge: conflict aborts cleanly, no partial commit of the agent lands" $?
run "$r" ok remove S-1 api
[ ! -d "$r/.claude/worktrees/sdlc-S-1-fix-api" ] && [ -d "$r/.claude/worktrees/sdlc-S-1-fix-web" ]
expect "remove: one tag leaves the others" $?

# --- merge: empty and dirty ----------------------------------------------------------------
r="$(fresh_repo)"
run "$r" ok add S-1 web
before="$(story_head "$r")"
run "$r" ok merge S-1 web
[ "$RC" -eq 4 ] && has "RESULT=empty" && [ "$(story_head "$r")" = "$before" ]
expect "merge: agent made no commit -> exit 4" $?
commit_in "$r" web apps/web/b.txt web1
echo stray > "$r/.claude/worktrees/sdlc-S-1-fix-web/uncommitted.txt"
run "$r" ok merge S-1 web
[ "$RC" -eq 6 ] && has "RESULT=dirty" && [ "$(story_head "$r")" = "$before" ]
expect "merge: uncommitted work in the fix worktree -> exit 6, nothing merged" $?
echo stray > "$r/.claude/worktrees/sdlc-S-1/uncommitted.txt"
rm "$r/.claude/worktrees/sdlc-S-1-fix-web/uncommitted.txt"
run "$r" ok merge S-1 web
[ "$RC" -eq 1 ] && has "RESULT=error" && [ "$(story_head "$r")" = "$before" ]
expect "merge: dirty story worktree -> exit 1, nothing merged" $?

echo "fix-worktrees: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
