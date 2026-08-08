#!/usr/bin/env bash
# migrate-memory-root.sh — NA-102. One-shot migration of the in-repo memory corpus
# (.claude/memories/{agents,reviews}) to the external root resolved by memory-root.sh (NA-101).
#
# usage:
#   migrate-memory-root.sh [--dry-run] [--force]
#
# SAFETY CONTRACT — copy, then verify, then delete, in that order, no exceptions:
#   1. Enumerate the tracked corpus via `git ls-files` — this is the EXACT set `git rm --cached`
#      will later remove. Verification and deletion always operate over this same set, never
#      over a directory walk that could silently diverge from it (a tracked-but-locally-deleted
#      file, a broken `find`, a symlinked directory `find` won't descend into, ...).
#   2. Refuse outright if that set is empty but the working tree still holds something at those
#      paths (inconsistent state), if it is non-empty in only one of agents/ or reviews/
#      (partial corpus), if any listed path is missing from disk or is a symlink, or if the
#      resolved destination sits inside this repository.
#   3. cp -R the two tracked trees to the resolved external root.
#   4. Verify EVERY tracked path individually: present at the destination AND checksum-equal.
#      A verification pass requires the matched count to equal the tracked count — an empty or
#      partially-enumerated set can never pass vacuously, because step 2 already refused it.
#   5. Only if verification passes: git rm -r --cached the two trees, delete the working
#      copies (checking its exit status), and commit — scoped to just those two paths, so an
#      operator's unrelated staged work is never swept in. A failure anywhere before step 5
#      completes leaves the repo's commit history untouched; a failure WITHIN step 5 (e.g. the
#      working-tree delete fails after the index removal already landed) restores the index via
#      `git reset` rather than leaving a half-staged, uncommitted mess.
#
# Never a raw `mv` — the source stays intact on disk until verification has already succeeded.
#
# --force additionally allows merging into an already non-empty destination (AC4), but still
# refuses if any tracked file would collide with — and silently clobber — existing destination
# content.
#
# Idempotent: once the corpus has been migrated, nothing is left tracked under those two paths,
# so a re-run finds nothing to do and exits 0 without touching anything.
#
# `.claude/memories/captured/` is untracked/gitignored and is intentionally NOT part of this
# migration — see NA-102.
#
# Bash 3.2 compatible: no associative arrays, no mapfile.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
. "$here/memory-root.sh"

usage() {
  printf 'usage: migrate-memory-root.sh [--dry-run] [--force]\n' >&2
}

# sdlc_mm_checksum <file> -> a content checksum, portable across the same hasher fallback chain
# memory-root.sh already uses. Returns non-zero (and prints why) if no hasher is available OR
# the file could not actually be read (e.g. a dangling symlink target) — a silent empty
# checksum must never be treated as "matches" by coincidence.
sdlc_mm_checksum() {
  local f="$1" line rc
  if command -v shasum >/dev/null 2>&1; then
    line="$(shasum -a 256 -- "$f" 2>/dev/null)"; rc=$?
  elif command -v sha256sum >/dev/null 2>&1; then
    line="$(sha256sum -- "$f" 2>/dev/null)"; rc=$?
  elif command -v cksum >/dev/null 2>&1; then
    line="$(cksum -- "$f" 2>/dev/null)"; rc=$?
  else
    printf 'migrate-memory-root: no shasum, sha256sum or cksum available — cannot verify\n' >&2
    return 1
  fi
  if [ "$rc" -ne 0 ] || [ -z "$line" ]; then
    printf 'migrate-memory-root: cannot read %s to checksum it\n' "$f" >&2
    return 1
  fi
  printf '%s\n' "$line" | awk '{print $1}'
}

# sdlc_mm_realpath <path> -> best-effort canonical absolute path: resolves symlinks in the
# longest EXISTING ancestor (the same way `git rev-parse --show-toplevel` resolves repo_root),
# then re-appends any non-existent trailing components literally. A plain string-prefix
# comparison between repo_root and dest_root would otherwise be foolable whenever one side is
# canonicalized and the other isn't (e.g. macOS's /var -> /private/var), which is exactly what
# would let a destination inside the repo slip past a naive check.
sdlc_mm_realpath() {
  local p="$1" tail="" existing
  while [ ! -d "$p" ] && [ "$p" != "/" ]; do
    tail="/$(basename "$p")$tail"
    p="$(dirname "$p")"
  done
  existing="$(cd "$p" 2>/dev/null && pwd -P)" || existing="$p"
  printf '%s%s\n' "$existing" "$tail"
}

# sdlc_mm_verify_entry <repo_root> <dest_root> <tracked-relpath> -> 0 iff the tracked path is a
# plain file (not a symlink) present at BOTH the source and destination with matching checksums.
# Read-only; prints one specific diagnostic and returns 1 on any disagreement.
sdlc_mm_verify_entry() {
  local repo_root="$1" dest_root="$2" relpath="$3"
  local src_abs="$repo_root/$relpath"
  local dest_relpath="${relpath#.claude/memories/}"
  local dest_abs="$dest_root/$dest_relpath"
  if [ -L "$src_abs" ]; then
    printf 'migrate-memory-root: symlinked corpus entries are not supported: %s\n' "$relpath" >&2
    return 1
  fi
  if [ ! -f "$src_abs" ]; then
    printf 'migrate-memory-root: tracked but missing on disk: %s\n' "$relpath" >&2
    return 1
  fi
  if [ ! -f "$dest_abs" ]; then
    printf 'migrate-memory-root: missing in destination: %s\n' "$dest_relpath" >&2
    return 1
  fi
  local s_sum d_sum
  s_sum="$(sdlc_mm_checksum "$src_abs")" || return 1
  d_sum="$(sdlc_mm_checksum "$dest_abs")" || return 1
  if [ "$s_sum" != "$d_sum" ]; then
    printf 'migrate-memory-root: checksum mismatch: %s\n' "$dest_relpath" >&2
    return 1
  fi
  return 0
}

sdlc_mm_main() {
  local dry_run=0 force=0 arg
  for arg in "$@"; do
    case "$arg" in
      --dry-run) dry_run=1 ;;
      --force) force=1 ;;
      -h|--help) usage; return 0 ;;
      *) printf 'migrate-memory-root: unknown argument: %s\n' "$arg" >&2; usage; return 1 ;;
    esac
  done

  local repo_root
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    printf 'migrate-memory-root: not inside a git repository\n' >&2
    return 1
  }

  # The authoritative source-of-truth list: EXACTLY the paths `git rm --cached` will remove.
  # Enumerated into a real temp file with its exit status checked — never a process substitution
  # here, whose failure `set -uo pipefail` (no `-e`, and `< <(...)` is not a pipeline) cannot see.
  local list_file
  list_file="$(mktemp 2>/dev/null)" || {
    printf 'migrate-memory-root: cannot create a temp file to enumerate the tracked corpus\n' >&2
    return 1
  }
  trap 'rm -f "$list_file"' RETURN
  if ! git -C "$repo_root" ls-files -z -- .claude/memories/agents .claude/memories/reviews > "$list_file"; then
    printf 'migrate-memory-root: git ls-files failed — cannot enumerate the tracked corpus\n' >&2
    return 1
  fi

  local total=0 agents_n=0 reviews_n=0 relpath
  while IFS= read -r -d '' relpath; do
    total=$((total + 1))
    case "$relpath" in
      .claude/memories/agents/*) agents_n=$((agents_n + 1)) ;;
      .claude/memories/reviews/*) reviews_n=$((reviews_n + 1)) ;;
    esac
  done < "$list_file"

  if [ "$total" -eq 0 ]; then
    if [ -d "$repo_root/.claude/memories/agents" ] || [ -d "$repo_root/.claude/memories/reviews" ]; then
      printf 'migrate-memory-root: nothing is tracked under .claude/memories/agents or .claude/memories/reviews, but an untracked directory of that name still exists under %s — resolve manually before re-running\n' \
        "$repo_root/.claude/memories" >&2
      return 1
    fi
    printf 'migrate-memory-root: nothing to migrate — .claude/memories/agents and .claude/memories/reviews are both untracked and absent; already migrated (no-op)\n'
    return 0
  fi
  if [ "$agents_n" -eq 0 ] || [ "$reviews_n" -eq 0 ]; then
    printf 'migrate-memory-root: partial corpus — %s tracked file(s) under agents/, %s under reviews/; refusing to guess, resolve manually\n' \
      "$agents_n" "$reviews_n" >&2
    return 1
  fi

  local dest_root
  dest_root="$(sdlc_memory_root)" || return 1

  local dest_root_real
  dest_root_real="$(sdlc_mm_realpath "$dest_root")"
  case "$dest_root_real" in
    "$repo_root")
      printf 'migrate-memory-root: destination root %s is the repository root — refusing\n' "$dest_root" >&2
      return 1
      ;;
    "$repo_root"/*)
      printf 'migrate-memory-root: destination root %s is inside the repository %s — refusing to copy the corpus into itself\n' \
        "$dest_root" "$repo_root" >&2
      return 1
      ;;
  esac

  local dest_agents="$dest_root/agents"
  local dest_reviews="$dest_root/reviews"
  local dest_nonempty=0
  [ -d "$dest_agents" ] && [ -n "$(find "$dest_agents" -type f 2>/dev/null)" ] && dest_nonempty=1
  [ -d "$dest_reviews" ] && [ -n "$(find "$dest_reviews" -type f 2>/dev/null)" ] && dest_nonempty=1
  if [ "$dest_nonempty" -eq 1 ] && [ "$force" -eq 0 ]; then
    printf 'migrate-memory-root: destination already has content under %s (agents/ or reviews/) — pass --force to merge into it\n' \
      "$dest_root" >&2
    return 1
  fi

  # Every tracked path must exist on disk, as a plain file, BEFORE anything destructive runs —
  # a path git still tracks but that is missing from the working tree (e.g. deleted-but-
  # uncommitted) would otherwise be silently dropped from both the copy and the eventual
  # `git rm --cached`, never having been inspected by verification at all.
  local disk_bad=0 abs
  while IFS= read -r -d '' relpath; do
    abs="$repo_root/$relpath"
    if [ -L "$abs" ]; then
      printf 'migrate-memory-root: symlinked corpus entries are not supported: %s\n' "$relpath" >&2
      disk_bad=1
    elif [ ! -f "$abs" ]; then
      printf 'migrate-memory-root: tracked but missing on disk: %s\n' "$relpath" >&2
      disk_bad=1
    fi
  done < "$list_file"
  if [ "$disk_bad" -eq 1 ]; then
    printf 'migrate-memory-root: refusing — the tracked corpus and the working tree disagree; repo left untouched\n' >&2
    return 1
  fi

  # --force merging into a non-empty destination must never silently clobber a colliding file.
  if [ "$force" -eq 1 ] && [ "$dest_nonempty" -eq 1 ]; then
    local collision=0 dest_relpath dest_abs
    while IFS= read -r -d '' relpath; do
      dest_relpath="${relpath#.claude/memories/}"
      dest_abs="$dest_root/$dest_relpath"
      if [ -e "$dest_abs" ]; then
        printf 'migrate-memory-root: --force collision — destination already has %s\n' "$dest_relpath" >&2
        collision=1
      fi
    done < "$list_file"
    if [ "$collision" -eq 1 ]; then
      printf 'migrate-memory-root: refusing to overwrite colliding destination file(s) under --force; repo left untouched\n' >&2
      return 1
    fi
  fi

  if [ "$dry_run" -eq 1 ]; then
    printf '[dry-run] would resolve memory root: %s\n' "$dest_root"
    printf '[dry-run] would copy %s tracked file(s): %s -> %s and %s -> %s\n' \
      "$total" "$repo_root/.claude/memories/agents" "$dest_agents" "$repo_root/.claude/memories/reviews" "$dest_reviews"
    printf '[dry-run] would verify every tracked path exists at the destination with a matching checksum\n'
    printf '[dry-run] would run: git -C %s rm -r --cached -- .claude/memories/agents .claude/memories/reviews\n' \
      "$repo_root"
    printf '[dry-run] would delete the working copies: %s %s\n' \
      "$repo_root/.claude/memories/agents" "$repo_root/.claude/memories/reviews"
    printf '[dry-run] would commit the removal, scoped to those two paths\n'
    return 0
  fi

  sdlc_memory_ensure "$dest_root" || return 1

  cp -R "$repo_root/.claude/memories/agents/." "$dest_agents/" || {
    printf 'migrate-memory-root: copy of %s failed — repo left untouched\n' "$repo_root/.claude/memories/agents" >&2
    return 1
  }
  cp -R "$repo_root/.claude/memories/reviews/." "$dest_reviews/" || {
    printf 'migrate-memory-root: copy of %s failed — repo left untouched\n' "$repo_root/.claude/memories/reviews" >&2
    return 1
  }

  local matched=0 verify_bad=0
  while IFS= read -r -d '' relpath; do
    if sdlc_mm_verify_entry "$repo_root" "$dest_root" "$relpath"; then
      matched=$((matched + 1))
    else
      verify_bad=1
    fi
  done < "$list_file"
  if [ "$verify_bad" -eq 1 ] || [ "$matched" -ne "$total" ]; then
    printf 'migrate-memory-root: verification FAILED — %s of %s tracked files verified at the destination; repo left untouched, the destination copy is not authoritative, safe to retry\n' \
      "$matched" "$total" >&2
    return 1
  fi
  printf 'migrate-memory-root: verification passed — all %s tracked files match at the destination\n' "$total"

  git -C "$repo_root" rm -r --cached --quiet -- .claude/memories/agents .claude/memories/reviews || {
    printf 'migrate-memory-root: git rm --cached failed — repo left in its prior committed state; nothing further touched\n' >&2
    return 1
  }

  local rm_rc
  rm -rf "$repo_root/.claude/memories/agents" "$repo_root/.claude/memories/reviews"
  rm_rc=$?
  if [ "$rm_rc" -ne 0 ]; then
    printf 'migrate-memory-root: deleting the working copies failed (rc=%s) — restoring the index so nothing is staged uncommitted\n' \
      "$rm_rc" >&2
    git -C "$repo_root" reset -q -- .claude/memories/agents .claude/memories/reviews 2>/dev/null
    printf 'migrate-memory-root: index restored; inspect %s manually (some files may already be gone) and re-run once the underlying issue is fixed\n' \
      "$repo_root/.claude/memories" >&2
    return 1
  fi

  git -C "$repo_root" commit --quiet -m 'chore(memory): migrate agent and review memory corpus to the external memory root' \
    -- .claude/memories/agents .claude/memories/reviews || {
    printf 'migrate-memory-root: commit failed — the removal is staged; inspect git status under %s and commit manually\n' \
      "$repo_root" >&2
    return 1
  }

  printf 'migrate-memory-root: migrated %s tracked files to %s; repo committed\n' "$total" "$dest_root"
  return 0
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  sdlc_mm_main "$@"
  exit $?
fi
