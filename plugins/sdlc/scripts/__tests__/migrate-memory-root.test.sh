#!/usr/bin/env bash
# migrate-memory-root.test.sh — NA-102. Contract suite for migrate-memory-root.sh.
#
# AUTHOR-RUN:
#   bash plugins/sdlc/scripts/__tests__/migrate-memory-root.test.sh
# Exit 0 = PASS, exit 1 = FAIL.
#
# Not yet wired into .github/workflows/ci.yml — that file is platform-engineer's, not this
# agent's, to edit; wiring it (or leaving it author-run-only by policy) is a separate call for
# the coordinator to make.
#
# HERMETICITY:
#   - every migration runs against a throwaway fixture repo under $tmp, with SDLC_MEMORY_ROOT
#     and HOME pointed inside $tmp — never the operator's real $HOME/.local/share or this real
#     repository's own tracked corpus.
#   - GIT_CONFIG_GLOBAL is pointed at a nonexistent file under $tmp and GIT_CONFIG_NOSYSTEM=1,
#     for every `git` invocation in this file (including inside migrate-memory-root.sh, since
#     they're exported): otherwise every `git init`/`commit` here runs under the OPERATOR's real
#     global gitconfig, and something as ordinary as `commit.gpgsign = true` turns migration
#     commits interactive/failing, breaking the suite on that operator's machine only.
#   - the AC-6 block below is the one deliberate exception to "throwaway fixture only": it reads
#     (never writes) THIS repo's real tracked corpus, but pinned to a fixed historical commit
#     (see AC-6 comment) rather than the live worktree, so it does not invert to failing once
#     the corpus this story adds the tooling for is actually migrated out of the live tree.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
mm="$here/../migrate-memory-root.sh"
fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n     %s\n' "$1" "$2"; fail=1; }

tmp="$(mktemp -d)"; tmp="$(cd "$tmp" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/home"
export GIT_CONFIG_GLOBAL="$tmp/gitconfig-does-not-exist"
export GIT_CONFIG_NOSYSTEM=1

# mk_memory_repo <dir> — a throwaway repo with a small, git-committed memory corpus under
# .claude/memories/{agents,reviews}, mirroring the real shape (per-agent subdirs, a nested
# file, multiple review files) without needing the real 273-file corpus.
mk_memory_repo() {
  local d="$1"
  mkdir -p "$d"
  git -C "$d" init -q
  git -C "$d" config user.email t@t
  git -C "$d" config user.name test
  mkdir -p "$d/.claude/memories/agents/agent-a" "$d/.claude/memories/agents/agent-b/nested" \
           "$d/.claude/memories/reviews"
  printf 'alpha\n'   > "$d/.claude/memories/agents/agent-a/one.md"
  printf 'beta\n'    > "$d/.claude/memories/agents/agent-b/two.md"
  printf 'gamma\n'   > "$d/.claude/memories/agents/agent-b/nested/three.md"
  printf 'delta\n'   > "$d/.claude/memories/reviews/review-one.md"
  printf 'epsilon\n' > "$d/.claude/memories/reviews/review-two.md"
  git -C "$d" add -A
  git -C "$d" commit -q -m 'seed memory corpus'
}

run_migrate() { # $1=repo dir  $2=dest root  [extra args...]
  local repo="$1" dest="$2"
  shift 2
  ( cd "$repo" && env -u XDG_DATA_HOME HOME="$tmp/home" SDLC_MEMORY_ROOT="$dest" bash "$mm" "$@" )
}

# ============================================================================================
# AC-6: documented per-agent/reviews file counts, verified read-only against a PINNED historical
# commit of this repo's real tracked corpus (f1f5d10 — the NA-101 merge, the last commit before
# this story's own work), not the live worktree. Pinning is deliberate: once this script's
# purpose is fulfilled and the corpus is actually migrated out, `git ls-files` against the LIVE
# tree would read 0 for every row below and this block would invert from a real gate into a
# permanent, meaningless failure. `git ls-tree` against a fixed, already-merged commit can never
# do that — that commit's content is immutable history.
# ============================================================================================
real_root="$(git -C "$here" rev-parse --show-toplevel)"
pinned_sha="f1f5d10c9d79d05cf0a63bf714b1fdd985bed32f"
check_count() { # $1=path relative to real_root  $2=expected count  $3=label
  local n
  n="$(git -C "$real_root" ls-tree -r --name-only "$pinned_sha" -- "$1" 2>/dev/null | wc -l | tr -d '[:space:]')"
  [ "$n" = "$2" ] && ok "(AC6) $3 tracked file count at $pinned_sha = $2" \
    || bad "(AC6) $3 tracked file count at $pinned_sha" "expected $2 got $n"
}
check_count ".claude/memories/agents/ai-enablement-engineer" 131 "ai-enablement-engineer"
check_count ".claude/memories/agents/web-engineer" 67 "web-engineer"
check_count ".claude/memories/agents/platform-engineer" 21 "platform-engineer"
check_count ".claude/memories/agents/knowledge-engineer" 14 "knowledge-engineer"
check_count ".claude/memories/agents/shared" 12 "shared"
check_count ".claude/memories/reviews" 28 "reviews"
total="$(git -C "$real_root" ls-tree -r --name-only "$pinned_sha" -- .claude/memories/agents .claude/memories/reviews 2>/dev/null | wc -l | tr -d '[:space:]')"
[ "$total" = "273" ] && ok "(AC6) total tracked corpus at $pinned_sha = 273" \
  || bad "(AC6) total tracked corpus at $pinned_sha" "got $total"

# ============================================================================================
# T1: happy path — copy, verify, git rm --cached, delete working copies, commit
# ============================================================================================
repo1="$tmp/repo1"; mk_memory_repo "$repo1"
dest1="$tmp/dest1"
out1="$(run_migrate "$repo1" "$dest1")"; rc1=$?
[ "$rc1" -eq 0 ] && ok "(T1a) happy-path migration exits 0" || bad "(T1a) exit code" "rc=$rc1 out='$out1'"

content_ok=1
for pair in "agents/agent-a/one.md:alpha" "agents/agent-b/two.md:beta" \
            "agents/agent-b/nested/three.md:gamma" "reviews/review-one.md:delta" \
            "reviews/review-two.md:epsilon"; do
  relpath="${pair%%:*}"; want="${pair##*:}"
  [ "$(cat "$dest1/$relpath" 2>/dev/null)" = "$want" ] || content_ok=0
done
[ "$content_ok" -eq 1 ] && ok "(T1b) every file landed at the destination with matching content" \
  || bad "(T1b) destination content" "one or more files missing/mismatched under $dest1"

{ [ ! -d "$repo1/.claude/memories/agents" ] && [ ! -d "$repo1/.claude/memories/reviews" ]; } \
  && ok "(T1c) working copies deleted from the repo" \
  || bad "(T1c) working copies" "agents or reviews still present under $repo1"

tracked1="$(git -C "$repo1" ls-files -- .claude/memories/agents .claude/memories/reviews)"
[ -z "$tracked1" ] && ok "(T1d) git no longer tracks the migrated trees" \
  || bad "(T1d) git tracking" "still tracked: $tracked1"

status1="$(git -C "$repo1" status --porcelain)"
[ -z "$status1" ] && ok "(T1e) working tree clean after the commit" \
  || bad "(T1e) working tree" "dirty: $status1"

log1="$(git -C "$repo1" log -1 --pretty=%s)"
printf '%s' "$log1" | grep -qi 'memory' \
  && ok "(T1f) a commit was created" || bad "(T1f) commit subject" "got '$log1'"

# ============================================================================================
# T2: non-empty destination refuses without --force, repo and destination left as they were
# ============================================================================================
repo2="$tmp/repo2"; mk_memory_repo "$repo2"
dest2="$tmp/dest2"
mkdir -p "$dest2/agents"
printf 'preexisting\n' > "$dest2/agents/stranger.md"
before_head2="$(git -C "$repo2" rev-parse HEAD)"
before_tree2="$(find "$repo2/.claude/memories" | sort)"
out2="$(run_migrate "$repo2" "$dest2" 2>&1)"; rc2=$?
after_head2="$(git -C "$repo2" rev-parse HEAD)"
after_tree2="$(find "$repo2/.claude/memories" | sort)"
{ [ "$rc2" -ne 0 ] && [ "$before_head2" = "$after_head2" ] && [ "$before_tree2" = "$after_tree2" ] \
  && printf '%s' "$out2" | grep -qi -- '--force'; } \
  && ok "(T2a) non-empty destination refuses without --force; repo untouched" \
  || bad "(T2a) non-empty destination refusal" "rc=$rc2 out='$out2'"
{ [ "$(cat "$dest2/agents/stranger.md")" = "preexisting" ] && [ ! -e "$dest2/agents/agent-a" ]; } \
  && ok "(T2b) destination not mutated by the refused run" \
  || bad "(T2b) destination mutation" "stranger.md or agent-a state changed under $dest2"

# ============================================================================================
# T3: --force merges into a non-empty destination (no collision) and completes the migration
# ============================================================================================
repo3="$tmp/repo3"; mk_memory_repo "$repo3"
dest3="$tmp/dest3"
mkdir -p "$dest3/agents"
printf 'preexisting\n' > "$dest3/agents/stranger.md"
out3="$(run_migrate "$repo3" "$dest3" --force)"; rc3=$?
{ [ "$rc3" -eq 0 ] && [ -f "$dest3/agents/stranger.md" ] && [ -f "$dest3/agents/agent-a/one.md" ] \
  && [ ! -d "$repo3/.claude/memories/agents" ] && [ ! -d "$repo3/.claude/memories/reviews" ]; } \
  && ok "(T3) --force merges into a non-empty destination and migration completes" \
  || bad "(T3) --force override" "rc=$rc3 out='$out3'"

# ============================================================================================
# T4: idempotent re-run after success is a safe no-op (no new commit, dest unchanged)
# ============================================================================================
repo4="$tmp/repo4"; mk_memory_repo "$repo4"
dest4="$tmp/dest4"
run_migrate "$repo4" "$dest4" >/dev/null
head4a="$(git -C "$repo4" rev-parse HEAD)"
dest4_snapshot="$(find "$dest4" -type f | sort)"
out4b="$(run_migrate "$repo4" "$dest4")"; rc4b=$?
head4b="$(git -C "$repo4" rev-parse HEAD)"
dest4_after="$(find "$dest4" -type f | sort)"
{ [ "$rc4b" -eq 0 ] && [ "$head4a" = "$head4b" ] && [ "$dest4_snapshot" = "$dest4_after" ] \
  && printf '%s' "$out4b" | grep -qi -- 'no-op\|already migrated\|nothing to migrate'; } \
  && ok "(T4) re-running after a successful migration is a safe no-op" \
  || bad "(T4) idempotent re-run" "rc=$rc4b out='$out4b' head1=$head4a head2=$head4b"

# ============================================================================================
# T5: a corrupted/truncated copy fails verification and leaves the repo untouched
#
# A PATH-shadowing `cp` wrapper performs the real copy and then corrupts one destination file
# — this exercises the script's own real verification step end-to-end (no test-only hook
# inside the script itself), mirroring memory-root.test.sh's R16 stub-PATH technique.
# ============================================================================================
repo5="$tmp/repo5"; mk_memory_repo "$repo5"
dest5="$tmp/dest5"
real_cp="$(command -v cp)"
stub_bin="$tmp/corrupt-bin"; mkdir -p "$stub_bin"
for c in bash git sed cut basename dirname tr head awk mkdir grep find wc rm printf shasum sha256sum cksum mktemp; do
  real="$(command -v "$c" 2>/dev/null)" || continue
  ln -sf "$real" "$stub_bin/$c"
done
corrupt_target="$dest5/agents/agent-b/nested/three.md"
cat > "$stub_bin/cp" <<EOF
#!/usr/bin/env bash
"$real_cp" "\$@"
rc=\$?
if [ -f "$corrupt_target" ]; then
  printf 'CORRUPTED\n' > "$corrupt_target"
fi
exit "\$rc"
EOF
chmod +x "$stub_bin/cp"

before_head5="$(git -C "$repo5" rev-parse HEAD)"
before_tree5="$(find "$repo5/.claude/memories" | sort)"
out5="$( cd "$repo5" && env -u XDG_DATA_HOME PATH="$stub_bin" HOME="$tmp/home" SDLC_MEMORY_ROOT="$dest5" bash "$mm" 2>&1 )"; rc5=$?
after_head5="$(git -C "$repo5" rev-parse HEAD)"
after_tree5="$(find "$repo5/.claude/memories" | sort)"
{ [ "$rc5" -ne 0 ] && [ "$before_head5" = "$after_head5" ] && [ "$before_tree5" = "$after_tree5" ] \
  && printf '%s' "$out5" | grep -qi 'verif'; } \
  && ok "(T5a) a corrupted copy fails verification, exits non-zero, and leaves the repo untouched" \
  || bad "(T5a) corrupted-copy verification" "rc=$rc5 out='$out5'"
[ "$(cat "$repo5/.claude/memories/agents/agent-b/nested/three.md")" = "gamma" ] \
  && ok "(T5b) the source file content is unchanged (only the disposable copy was corrupted)" \
  || bad "(T5b) source content" "source file mutated"
tracked5="$(git -C "$repo5" ls-files -- .claude/memories/agents .claude/memories/reviews)"
[ -n "$tracked5" ] && ok "(T5c) git still tracks the corpus after the failed run" \
  || bad "(T5c) git tracking after failure" "corpus untracked despite a failed verification"

# ============================================================================================
# T6: --dry-run reports intent and mutates nothing (repo untouched, destination not created)
# ============================================================================================
repo6="$tmp/repo6"; mk_memory_repo "$repo6"
dest6="$tmp/dest6"
before_head6="$(git -C "$repo6" rev-parse HEAD)"
before_tree6="$(find "$repo6/.claude/memories" | sort)"
out6="$(run_migrate "$repo6" "$dest6" --dry-run)"; rc6=$?
after_head6="$(git -C "$repo6" rev-parse HEAD)"
after_tree6="$(find "$repo6/.claude/memories" | sort)"
{ [ "$rc6" -eq 0 ] && [ "$before_head6" = "$after_head6" ] && [ "$before_tree6" = "$after_tree6" ] \
  && [ ! -e "$dest6" ] && printf '%s' "$out6" | grep -qi 'dry-run'; } \
  && ok "(T6a) --dry-run exits 0, reports intent, and creates no destination" \
  || bad "(T6a) dry-run happy path" "rc=$rc6 out='$out6' dest_exists=$([ -e "$dest6" ] && echo yes || echo no)"

# --dry-run against an already-non-empty destination still refuses (and still mutates nothing)
dest6b="$tmp/dest6b"
mkdir -p "$dest6b/reviews"
printf 'preexisting\n' > "$dest6b/reviews/stranger.md"
before_tree6b="$(find "$dest6b" | sort)"
out6b="$(run_migrate "$repo6" "$dest6b" --dry-run 2>&1)"; rc6b=$?
after_tree6b="$(find "$dest6b" | sort)"
{ [ "$rc6b" -ne 0 ] && [ "$before_tree6b" = "$after_tree6b" ] \
  && printf '%s' "$out6b" | grep -qi -- '--force'; } \
  && ok "(T6b) --dry-run against a non-empty destination still refuses without --force" \
  || bad "(T6b) dry-run non-empty destination" "rc=$rc6b out='$out6b'"

# ============================================================================================
# T7: a partial corpus (only agents/ actually tracked, reviews/ fully untracked+removed) is a
# hard refusal, not a guess. Genuinely untracks reviews/ via `git rm --cached` (not just an
# `rm -rf` of the working tree, which would instead be a T10-shaped tracked-but-missing case).
# ============================================================================================
repo7="$tmp/repo7"; mk_memory_repo "$repo7"
git -C "$repo7" rm -r --cached --quiet -- .claude/memories/reviews
rm -rf "$repo7/.claude/memories/reviews"
git -C "$repo7" commit -q -m 'untrack reviews for the test fixture'
dest7="$tmp/dest7"
before_head7="$(git -C "$repo7" rev-parse HEAD 2>/dev/null)"
out7="$(run_migrate "$repo7" "$dest7" 2>&1)"; rc7=$?
after_head7="$(git -C "$repo7" rev-parse HEAD 2>/dev/null)"
{ [ "$rc7" -ne 0 ] && [ "$before_head7" = "$after_head7" ] && printf '%s' "$out7" | grep -qi 'partial'; } \
  && ok "(T7) a partial corpus (only agents/ tracked) is a hard refusal, not a guess" \
  || bad "(T7) partial corpus" "rc=$rc7 out='$out7'"

# ============================================================================================
# T8: an unknown flag is rejected
# ============================================================================================
repo8="$tmp/repo8"; mk_memory_repo "$repo8"
dest8="$tmp/dest8"
out8="$(run_migrate "$repo8" "$dest8" --bogus 2>&1)"; rc8=$?
[ "$rc8" -ne 0 ] && printf '%s' "$out8" | grep -qi 'unknown argument' \
  && ok "(T8) an unrecognised argument is rejected with a clear message" \
  || bad "(T8) unknown argument" "rc=$rc8 out='$out8'"

# ============================================================================================
# T9 (CRITICAL 1 regression): a sparse/empty checkout — the corpus is fully TRACKED but absent
# from the working tree entirely. Independently verified against the pre-fix script (saved from
# commit f341e5f) BEFORE writing this fix: it silently reported "already migrated (no-op)"
# without ever having copied anything anywhere — a false idempotency claim that leaves the
# corpus reachable ONLY via git history once someone later runs an actual `git rm`. The fixed
# script must refuse loudly instead.
# ============================================================================================
repo9="$tmp/repo9"; mk_memory_repo "$repo9"
git -C "$repo9" sparse-checkout init --cone >/dev/null
git -C "$repo9" sparse-checkout set --skip-checks nonexistent-placeholder >/dev/null
dest9="$tmp/dest9"
before_head9="$(git -C "$repo9" rev-parse HEAD)"
out9="$(run_migrate "$repo9" "$dest9" 2>&1)"; rc9=$?
after_head9="$(git -C "$repo9" rev-parse HEAD)"
{ [ "$rc9" -ne 0 ] && [ "$before_head9" = "$after_head9" ] \
  && ! printf '%s' "$out9" | grep -qi 'already migrated' \
  && [ ! -e "$dest9" ]; } \
  && ok "(T9) a tracked-but-not-checked-out corpus refuses rather than falsely claiming no-op" \
  || bad "(T9) sparse checkout" "rc=$rc9 out='$out9' dest_exists=$([ -e "$dest9" ] && echo yes || echo no)"

# ============================================================================================
# T10 (CRITICAL 2 regression): one tracked file deleted from the working tree but never
# committed — an entirely ordinary local state. Independently verified against the pre-fix
# script BEFORE writing this fix: it silently completed (verification never saw the missing
# file because it walked `find`, not the tracked set), then `git rm --cached` dropped the file
# from the index too — leaving it neither at the destination nor at the new HEAD, recoverable
# only from old history. The fixed script must refuse and leave the file tracked at HEAD.
# ============================================================================================
repo10="$tmp/repo10"; mk_memory_repo "$repo10"
rm "$repo10/.claude/memories/agents/agent-b/two.md"
dest10="$tmp/dest10"
before_head10="$(git -C "$repo10" rev-parse HEAD)"
out10="$(run_migrate "$repo10" "$dest10" 2>&1)"; rc10=$?
after_head10="$(git -C "$repo10" rev-parse HEAD)"
still_tracked10="NO"
git -C "$repo10" cat-file -e "HEAD:.claude/memories/agents/agent-b/two.md" 2>/dev/null && still_tracked10="YES"
{ [ "$rc10" -ne 0 ] && [ "$before_head10" = "$after_head10" ] && [ "$still_tracked10" = "YES" ] \
  && printf '%s' "$out10" | grep -qi 'missing on disk'; } \
  && ok "(T10) a tracked-but-uncommitted-deleted file refuses; nothing dropped from HEAD" \
  || bad "(T10) uncommitted delete" "rc=$rc10 out='$out10' still_tracked=$still_tracked10"

# ============================================================================================
# T11 (IMPORTANT 3 regression): the working-tree delete (`rm -rf`) fails after `git rm --cached`
# already succeeded. Independently verified against the pre-fix script BEFORE writing this fix:
# it printed the `rm` permission error but then committed anyway and reported success (rc=0).
# The fixed script must fail loudly AND restore the index (`git reset`) rather than leave a
# half-staged, uncommitted removal.
# ============================================================================================
repo11="$tmp/repo11"; mk_memory_repo "$repo11"
chmod 555 "$repo11/.claude/memories/agents"
dest11="$tmp/dest11"
before_head11="$(git -C "$repo11" rev-parse HEAD)"
out11="$(run_migrate "$repo11" "$dest11" 2>&1)"; rc11=$?
chmod 755 "$repo11/.claude/memories/agents" 2>/dev/null || true
after_head11="$(git -C "$repo11" rev-parse HEAD)"
staged11="$(git -C "$repo11" diff --cached --name-only)"
{ [ "$rc11" -ne 0 ] && [ "$before_head11" = "$after_head11" ] && [ -z "$staged11" ] \
  && printf '%s' "$out11" | grep -qi 'restoring the index'; } \
  && ok "(T11) an rm -rf failure after git rm --cached surfaces as a failure with the index restored" \
  || bad "(T11) rm -rf failure" "rc=$rc11 out='$out11' staged='$staged11'"
rm -rf "$repo11/.claude/memories/agents" 2>/dev/null || true

# ============================================================================================
# T12 (IMPORTANT 4 regression): an operator's unrelated file is already staged before the
# migration runs. Independently verified against the pre-fix script BEFORE writing this fix: it
# swept the unrelated staged file into the migration commit. The fixed script's commit must be
# pathspec-scoped to just the two migrated trees.
# ============================================================================================
repo12="$tmp/repo12"; mk_memory_repo "$repo12"
printf 'unrelated wip\n' > "$repo12/unrelated.txt"
git -C "$repo12" add unrelated.txt
dest12="$tmp/dest12"
out12="$(run_migrate "$repo12" "$dest12")"; rc12=$?
in_commit12="NO"
git -C "$repo12" show --name-only --pretty=format: HEAD 2>/dev/null | grep -q '^unrelated.txt$' && in_commit12="YES"
still_staged12="NO"
git -C "$repo12" diff --cached --name-only 2>/dev/null | grep -q '^unrelated.txt$' && still_staged12="YES"
{ [ "$rc12" -eq 0 ] && [ "$in_commit12" = "NO" ] && [ "$still_staged12" = "YES" ]; } \
  && ok "(T12) an unrelated pre-staged file is not swept into the migration commit" \
  || bad "(T12) commit pathspec scoping" "rc=$rc12 out='$out12' in_commit=$in_commit12 still_staged=$still_staged12"

# ============================================================================================
# T13 (IMPORTANT 5 regression): --force must not silently clobber a colliding destination file
# with distinct content. Independently verified against the pre-fix script BEFORE writing this
# fix: it overwrote the destination file with no warning and rc=0. The fixed script must refuse
# and leave the destination content untouched.
# ============================================================================================
repo13="$tmp/repo13"; mk_memory_repo "$repo13"
dest13="$tmp/dest13"
mkdir -p "$dest13/agents/agent-a"
printf 'DISTINCT EXTERNAL CONTENT\n' > "$dest13/agents/agent-a/one.md"
out13="$(run_migrate "$repo13" "$dest13" --force 2>&1)"; rc13=$?
after13="$(cat "$dest13/agents/agent-a/one.md" 2>/dev/null)"
{ [ "$rc13" -ne 0 ] && [ "$after13" = "DISTINCT EXTERNAL CONTENT" ] \
  && printf '%s' "$out13" | grep -qi 'collision'; } \
  && ok "(T13) --force refuses on a colliding destination file rather than clobbering it" \
  || bad "(T13) force collision" "rc=$rc13 out='$out13' dest_content='$after13'"

# ============================================================================================
# T14 (IMPORTANT 6 regression): the resolved destination sits inside the repository itself.
# Independently verified against the pre-fix script BEFORE writing this fix: `cp -R` recursed
# into its own output (agents/agents/agents/...) until "File name too long", leaving the
# tracked corpus directory polluted with a nested `agents/` and a `captured/` tree that
# `git status` collapses into one innocuous-looking `??` line. The fixed script must refuse
# before any `cp` runs at all.
# ============================================================================================
repo14="$tmp/repo14"; mk_memory_repo "$repo14"
before_head14="$(git -C "$repo14" rev-parse HEAD)"
before_count14="$(find "$repo14/.claude/memories" -type f | wc -l | tr -d ' ')"
dest14="$repo14/.claude/memories/agents"
out14="$(run_migrate "$repo14" "$dest14" 2>&1)"; rc14=$?
after_head14="$(git -C "$repo14" rev-parse HEAD)"
after_count14="$(find "$repo14/.claude/memories" -type f 2>/dev/null | wc -l | tr -d ' ')"
{ [ "$rc14" -ne 0 ] && [ "$before_head14" = "$after_head14" ] && [ "$before_count14" = "$after_count14" ] \
  && printf '%s' "$out14" | grep -qi 'inside the repository'; } \
  && ok "(T14) a destination inside the repository is refused before any copy runs" \
  || bad "(T14) destination inside repo" "rc=$rc14 out='$out14' count_before=$before_count14 count_after=$after_count14"

# ============================================================================================
# T15 (MINOR 11 regression): a tracked corpus entry that is ITSELF a symlink (not merely a path
# traversing one) is refused outright rather than being silently copied structurally (as a
# symlink, not its content) and left to potentially dangle at the destination once the source
# is deleted.
# ============================================================================================
repo15="$tmp/repo15"; mk_memory_repo "$repo15"
ln -s ../../../../outside-the-corpus.md "$repo15/.claude/memories/agents/agent-a/evil-link.md"
git -C "$repo15" add "$repo15/.claude/memories/agents/agent-a/evil-link.md"
git -C "$repo15" commit -q -m 'add a symlinked corpus entry for the test fixture'
dest15="$tmp/dest15"
before_head15="$(git -C "$repo15" rev-parse HEAD)"
out15="$(run_migrate "$repo15" "$dest15" 2>&1)"; rc15=$?
after_head15="$(git -C "$repo15" rev-parse HEAD)"
{ [ "$rc15" -ne 0 ] && [ "$before_head15" = "$after_head15" ] \
  && printf '%s' "$out15" | grep -qi 'symlink'; } \
  && ok "(T15) a symlinked tracked corpus entry is refused, not silently migrated structurally" \
  || bad "(T15) symlinked entry" "rc=$rc15 out='$out15'"

exit "$fail"
