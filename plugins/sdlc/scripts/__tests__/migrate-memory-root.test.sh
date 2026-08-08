#!/usr/bin/env bash
# migrate-memory-root.test.sh — NA-102. Contract suite for migrate-memory-root.sh.
#
# AUTHOR-RUN AND CI-WIRED:
#   bash plugins/sdlc/scripts/__tests__/migrate-memory-root.test.sh
# Exit 0 = PASS, exit 1 = FAIL.
#
# HERMETICITY: every migration runs against a throwaway fixture repo under $tmp, with
# SDLC_MEMORY_ROOT and HOME pointed inside $tmp — never the operator's real
# $HOME/.local/share or this real repository's own tracked corpus. The AC-6 block below is
# the one deliberate exception: it reads (never writes) THIS repo's real tracked file counts
# via `git ls-files`, which is read-only and safe.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
mm="$here/../migrate-memory-root.sh"
fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n     %s\n' "$1" "$2"; fail=1; }

tmp="$(mktemp -d)"; tmp="$(cd "$tmp" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/home"

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
# AC-6: documented per-agent/reviews file counts, verified read-only against THIS repo's real
# tracked corpus (not a fixture) — the migration is never executed for real here.
# ============================================================================================
real_root="$(git -C "$here" rev-parse --show-toplevel)"
check_count() { # $1=path relative to real_root  $2=expected count  $3=label
  local n
  n="$(git -C "$real_root" ls-files -- "$1" | wc -l | tr -d '[:space:]')"
  [ "$n" = "$2" ] && ok "(AC6) $3 tracked file count = $2" \
    || bad "(AC6) $3 tracked file count" "expected $2 got $n"
}
check_count ".claude/memories/agents/ai-enablement-engineer" 131 "ai-enablement-engineer"
check_count ".claude/memories/agents/web-engineer" 67 "web-engineer"
check_count ".claude/memories/agents/platform-engineer" 21 "platform-engineer"
check_count ".claude/memories/agents/knowledge-engineer" 14 "knowledge-engineer"
check_count ".claude/memories/agents/shared" 12 "shared"
check_count ".claude/memories/reviews" 28 "reviews"
total="$(git -C "$real_root" ls-files -- .claude/memories/agents .claude/memories/reviews | wc -l | tr -d '[:space:]')"
[ "$total" = "273" ] && ok "(AC6) total tracked corpus = 273" || bad "(AC6) total tracked corpus" "got $total"

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
# T3: --force merges into a non-empty destination and completes the migration
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
for c in bash git sed cut basename dirname tr head awk mkdir grep find wc rm printf shasum sha256sum cksum; do
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
# T7 (bonus): a partial corpus (only one of agents/reviews present) is a hard refusal
# ============================================================================================
repo7="$tmp/repo7"; mk_memory_repo "$repo7"
rm -rf "$repo7/.claude/memories/reviews"
dest7="$tmp/dest7"
before_head7="$(git -C "$repo7" rev-parse HEAD 2>/dev/null)"
out7="$(run_migrate "$repo7" "$dest7" 2>&1)"; rc7=$?
after_head7="$(git -C "$repo7" rev-parse HEAD 2>/dev/null)"
{ [ "$rc7" -ne 0 ] && [ "$before_head7" = "$after_head7" ] && printf '%s' "$out7" | grep -qi 'partial'; } \
  && ok "(T7) a partial corpus (only agents present) is a hard refusal, not a guess" \
  || bad "(T7) partial corpus" "rc=$rc7 out='$out7'"

# ============================================================================================
# T8 (bonus): an unknown flag is rejected
# ============================================================================================
repo8="$tmp/repo8"; mk_memory_repo "$repo8"
dest8="$tmp/dest8"
out8="$(run_migrate "$repo8" "$dest8" --bogus 2>&1)"; rc8=$?
[ "$rc8" -ne 0 ] && printf '%s' "$out8" | grep -qi 'unknown argument' \
  && ok "(T8) an unrecognised argument is rejected with a clear message" \
  || bad "(T8) unknown argument" "rc=$rc8 out='$out8'"

exit "$fail"
